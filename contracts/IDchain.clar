(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROFILE_EXISTS (err u101))
(define-constant ERR_PROFILE_NOT_FOUND (err u102))
(define-constant ERR_INVALID_VERIFICATION_LEVEL (err u103))
(define-constant ERR_INSUFFICIENT_VERIFICATION (err u104))
(define-constant ERR_VERIFIER_NOT_AUTHORIZED (err u105))
(define-constant ERR_PROFILE_SUSPENDED (err u106))
(define-constant ERR_INVALID_DATA (err u107))
(define-constant ERR_HISTORY_NOT_FOUND (err u108))
(define-constant ERR_INVALID_HISTORY_TYPE (err u109))

(define-data-var profile-counter uint u0)
(define-data-var history-counter uint u0)
(define-data-var contract-paused bool false)

(define-map kyc-profiles
  { profile-id: uint }
  {
    owner: principal,
    verification-level: uint,
    verified-at: uint,
    verifier: principal,
    status: (string-ascii 20),
    metadata-hash: (string-ascii 64),
    created-at: uint,
    updated-at: uint
  }
)

(define-map user-profiles
  { user: principal }
  { profile-id: uint }
)

(define-map authorized-verifiers
  { verifier: principal }
  { 
    authorized: bool,
    verification-limit: uint,
    added-at: uint
  }
)

(define-map profile-attributes
  { profile-id: uint, attribute: (string-ascii 32) }
  { 
    value: (string-ascii 128),
    verified: bool,
    verified-by: (optional principal),
    updated-at: uint
  }
)

(define-map verification-requests
  { request-id: uint }
  {
    profile-id: uint,
    requester: principal,
    verifier: principal,
    status: (string-ascii 20),
    requested-at: uint,
    processed-at: (optional uint)
  }
)

(define-data-var request-counter uint u0)

(define-map profile-history
  { history-id: uint }
  {
    profile-id: uint,
    action-type: (string-ascii 32),
    old-value: (optional (string-ascii 128)),
    new-value: (optional (string-ascii 128)),
    field-name: (string-ascii 32),
    changed-by: principal,
    timestamp: uint,
    transaction-id: (string-ascii 64),
    additional-data: (optional (string-ascii 256))
  }
)

(define-map profile-history-index
  { profile-id: uint }
  { 
    history-count: uint,
    last-updated: uint
  }
)

(define-map history-analytics
  { profile-id: uint, action-type: (string-ascii 32) }
  {
    count: uint,
    first-occurrence: uint,
    last-occurrence: uint
  }
)

(define-map trusted-history-readers
  { reader: principal }
  {
    authorized: bool,
    access-level: uint,
    granted-by: principal,
    granted-at: uint
  }
)

(define-private (record-history-entry (profile-id uint) (action-type (string-ascii 32)) (field-name (string-ascii 32)) (old-value (optional (string-ascii 128))) (new-value (optional (string-ascii 128))) (additional-data (optional (string-ascii 256))))
  (let
    (
      (history-id (+ (var-get history-counter) u1))
      (current-time stacks-block-height)
      (tx-id (int-to-ascii (to-int stacks-block-height)))
      (current-index (default-to { history-count: u0, last-updated: u0 } (map-get? profile-history-index { profile-id: profile-id })))
      (current-analytics (default-to { count: u0, first-occurrence: u0, last-occurrence: u0 } (map-get? history-analytics { profile-id: profile-id, action-type: action-type })))
    )
    
    (map-set profile-history
      { history-id: history-id }
      {
        profile-id: profile-id,
        action-type: action-type,
        old-value: old-value,
        new-value: new-value,
        field-name: field-name,
        changed-by: tx-sender,
        timestamp: current-time,
        transaction-id: tx-id,
        additional-data: additional-data
      }
    )
    
    (map-set profile-history-index
      { profile-id: profile-id }
      {
        history-count: (+ (get history-count current-index) u1),
        last-updated: current-time
      }
    )
    
    (map-set history-analytics
      { profile-id: profile-id, action-type: action-type }
      {
        count: (+ (get count current-analytics) u1),
        first-occurrence: (if (is-eq (get count current-analytics) u0) current-time (get first-occurrence current-analytics)),
        last-occurrence: current-time
      }
    )
    
    (var-set history-counter history-id)
    (ok history-id)
  )
)

(define-public (grant-history-access (reader principal) (access-level uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= access-level u3) ERR_INVALID_DATA)
    
    (map-set trusted-history-readers
      { reader: reader }
      {
        authorized: true,
        access-level: access-level,
        granted-by: tx-sender,
        granted-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (revoke-history-access (reader principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-delete trusted-history-readers { reader: reader })
    (ok true)
  )
)

(define-public (create-profile (metadata-hash (string-ascii 64)))
  (let
    (
      (profile-id (+ (var-get profile-counter) u1))
      (current-block stacks-block-height)
    )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (map-get? user-profiles { user: tx-sender })) ERR_PROFILE_EXISTS)
    (asserts! (> (len metadata-hash) u0) ERR_INVALID_DATA)
    
    (map-set kyc-profiles
      { profile-id: profile-id }
      {
        owner: tx-sender,
        verification-level: u0,
        verified-at: u0,
        verifier: tx-sender,
        status: "pending",
        metadata-hash: metadata-hash,
        created-at: current-block,
        updated-at: current-block
      }
    )
    
    (map-set user-profiles
      { user: tx-sender }
      { profile-id: profile-id }
    )
    
    (var-set profile-counter profile-id)
    (unwrap-panic (record-history-entry profile-id "profile-created" "status" none (some "pending") (some metadata-hash)))
    (ok profile-id)
  )
)

(define-public (add-verifier (verifier principal) (verification-limit uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set authorized-verifiers
      { verifier: verifier }
      {
        authorized: true,
        verification-limit: verification-limit,
        added-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-delete authorized-verifiers { verifier: verifier })
    (ok true)
  )
)

(define-public (verify-profile (profile-id uint) (verification-level uint))
  (let
    (
      (profile (unwrap! (map-get? kyc-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
      (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR_VERIFIER_NOT_AUTHORIZED))
      (current-block stacks-block-height)
    )
    (asserts! (get authorized verifier-info) ERR_VERIFIER_NOT_AUTHORIZED)
    (asserts! (<= verification-level (get verification-limit verifier-info)) ERR_INVALID_VERIFICATION_LEVEL)
    (asserts! (is-eq (get status profile) "pending") ERR_PROFILE_SUSPENDED)
    
    (map-set kyc-profiles
      { profile-id: profile-id }
      (merge profile {
        verification-level: verification-level,
        verified-at: current-block,
        verifier: tx-sender,
        status: "verified",
        updated-at: current-block
      })
    )
    (unwrap-panic (record-history-entry profile-id "profile-verified" "status" (some (get status profile)) (some "verified") (some (int-to-ascii (to-int verification-level)))))
    (ok true)
  )
)

(define-public (suspend-profile (profile-id uint))
  (let
    (
      (profile (unwrap! (map-get? kyc-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get verifier profile))) ERR_NOT_AUTHORIZED)
    
    (map-set kyc-profiles
      { profile-id: profile-id }
      (merge profile {
        status: "suspended",
        updated-at: stacks-block-height
      })
    )
    (ok true)
  )
)

(define-public (update-profile-metadata (profile-id uint) (metadata-hash (string-ascii 64)))
  (let
    (
      (profile (unwrap! (map-get? kyc-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner profile)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len metadata-hash) u0) ERR_INVALID_DATA)
    
    (map-set kyc-profiles
      { profile-id: profile-id }
      (merge profile {
        metadata-hash: metadata-hash,
        updated-at: stacks-block-height
      })
    )
    (ok true)
  )
)

(define-public (add-profile-attribute (profile-id uint) (attribute (string-ascii 32)) (value (string-ascii 128)))
  (let
    (
      (profile (unwrap! (map-get? kyc-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner profile)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len attribute) u0) ERR_INVALID_DATA)
    
    (map-set profile-attributes
      { profile-id: profile-id, attribute: attribute }
      {
        value: value,
        verified: false,
        verified-by: none,
        updated-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (verify-attribute (profile-id uint) (attribute (string-ascii 32)))
  (let
    (
      (attr (unwrap! (map-get? profile-attributes { profile-id: profile-id, attribute: attribute }) ERR_PROFILE_NOT_FOUND))
      (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR_VERIFIER_NOT_AUTHORIZED))
    )
    (asserts! (get authorized verifier-info) ERR_VERIFIER_NOT_AUTHORIZED)
    
    (map-set profile-attributes
      { profile-id: profile-id, attribute: attribute }
      (merge attr {
        verified: true,
        verified-by: (some tx-sender),
        updated-at: stacks-block-height
      })
    )
    (ok true)
  )
)

(define-public (request-verification (profile-id uint) (verifier principal))
  (let
    (
      (request-id (+ (var-get request-counter) u1))
      (profile (unwrap! (map-get? kyc-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
      (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: verifier }) ERR_VERIFIER_NOT_AUTHORIZED))
    )
    (asserts! (is-eq tx-sender (get owner profile)) ERR_NOT_AUTHORIZED)
    (asserts! (get authorized verifier-info) ERR_VERIFIER_NOT_AUTHORIZED)
    
    (map-set verification-requests
      { request-id: request-id }
      {
        profile-id: profile-id,
        requester: tx-sender,
        verifier: verifier,
        status: "pending",
        requested-at: stacks-block-height,
        processed-at: none
      }
    )
    
    (var-set request-counter request-id)
    (ok request-id)
  )
)

(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

(define-read-only (get-profile (profile-id uint))
  (map-get? kyc-profiles { profile-id: profile-id })
)

(define-read-only (get-user-profile (user principal))
  (match (map-get? user-profiles { user: user })
    profile-data (map-get? kyc-profiles { profile-id: (get profile-id profile-data) })
    none
  )
)

(define-read-only (get-profile-attribute (profile-id uint) (attribute (string-ascii 32)))
  (map-get? profile-attributes { profile-id: profile-id, attribute: attribute })
)

(define-read-only (is-profile-verified (profile-id uint) (min-level uint))
  (match (map-get? kyc-profiles { profile-id: profile-id })
    profile (and 
      (>= (get verification-level profile) min-level)
      (is-eq (get status profile) "verified")
    )
    false
  )
)

(define-read-only (is-verifier-authorized (verifier principal))
  (match (map-get? authorized-verifiers { verifier: verifier })
    verifier-info (get authorized verifier-info)
    false
  )
)

(define-read-only (get-verification-request (request-id uint))
  (map-get? verification-requests { request-id: request-id })
)

(define-read-only (get-profile-count)
  (var-get profile-counter)
)

(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

(define-read-only (get-history-entry (history-id uint))
  (map-get? profile-history { history-id: history-id })
)

(define-read-only (get-profile-history-summary (profile-id uint))
  (map-get? profile-history-index { profile-id: profile-id })
)

(define-read-only (get-history-analytics (profile-id uint) (action-type (string-ascii 32)))
  (map-get? history-analytics { profile-id: profile-id, action-type: action-type })
)

(define-read-only (get-history-reader-access (reader principal))
  (map-get? trusted-history-readers { reader: reader })
)

(define-read-only (can-read-history (profile-id uint) (reader principal))
  (let
    (
      (profile (map-get? kyc-profiles { profile-id: profile-id }))
      (reader-access (map-get? trusted-history-readers { reader: reader }))
    )
    (or
      (and (is-some profile) (is-eq reader (get owner (unwrap-panic profile))))
      (is-eq reader CONTRACT_OWNER)
      (and (is-some reader-access) (get authorized (unwrap-panic reader-access)))
    )
  )
)

(define-read-only (get-total-history-entries)
  (var-get history-counter)
)

(define-public (get-profile-history-range (profile-id uint) (start-id uint) (limit uint))
  (let
    (
      (reader-authorized (can-read-history profile-id tx-sender))
    )
    (asserts! reader-authorized ERR_NOT_AUTHORIZED)
    (asserts! (> limit u0) ERR_INVALID_DATA)
    (asserts! (<= limit u50) ERR_INVALID_DATA)
    
    (ok (get-history-entries-by-range start-id limit profile-id))
  )
)

(define-private (get-history-entries-by-range (start-id uint) (limit uint) (target-profile-id uint))
  (let
    (
      (entry-1 (filter-history-entry start-id target-profile-id))
      (entry-2 (filter-history-entry (+ start-id u1) target-profile-id))
      (entry-3 (filter-history-entry (+ start-id u2) target-profile-id))
      (entry-4 (filter-history-entry (+ start-id u3) target-profile-id))
      (entry-5 (filter-history-entry (+ start-id u4) target-profile-id))
    )
    (list entry-1 entry-2 entry-3 entry-4 entry-5)
  )
)

(define-private (filter-history-entry (history-id uint) (target-profile-id uint))
  (match (map-get? profile-history { history-id: history-id })
    entry (if (is-eq (get profile-id entry) target-profile-id) (some entry) none)
    none
  )
)