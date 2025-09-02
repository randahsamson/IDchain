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
(define-constant ERR_INVALID_REPUTATION_SCORE (err u110))
(define-constant ERR_ENDORSEMENT_EXISTS (err u111))
(define-constant ERR_SELF_ENDORSEMENT (err u112))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u113))
(define-constant ERR_PROFILE_EXPIRED (err u114))
(define-constant ERR_RENEWAL_PENDING (err u115))
(define-constant ERR_NOT_RENEWABLE (err u116))
(define-constant ERR_RENEWAL_NOT_FOUND (err u117))

(define-data-var profile-counter uint u0)
(define-data-var history-counter uint u0)
(define-data-var contract-paused bool false)
(define-data-var endorsement-counter uint u0)
(define-data-var reputation-decay-rate uint u10)
(define-data-var default-profile-validity-period uint u52560) ;; ~1 year in blocks
(define-data-var renewal-grace-period uint u1440) ;; ~1 week grace period
(define-data-var total-renewals uint u0)

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

(define-map profile-reputation
  { profile-id: uint }
  {
    base-score: uint,
    verification-bonus: uint,
    endorsement-score: uint,
    time-penalty: uint,
    last-updated: uint,
    total-score: uint
  }
)

(define-map verifier-reputation
  { verifier: principal }
  {
    total-verifications: uint,
    successful-verifications: uint,
    reputation-weight: uint,
    last-activity: uint
  }
)

(define-map profile-endorsements
  { endorsement-id: uint }
  {
    endorser-profile: uint,
    endorsed-profile: uint,
    endorsement-weight: uint,
    endorsement-type: (string-ascii 32),
    created-at: uint,
    active: bool
  }
)

(define-map endorsement-summary
  { profile-id: uint }
  {
    total-endorsements: uint,
    weighted-endorsement-score: uint,
    last-endorsement: uint
  }
)

(define-map reputation-thresholds
  { threshold-name: (string-ascii 32) }
  {
    min-score: uint,
    description: (string-ascii 64)
  }
)

(define-map profile-expiration
  { profile-id: uint }
  {
    expiry-block: uint,
    renewal-count: uint,
    last-renewal-block: uint,
    auto-renewal-enabled: bool,
    status: (string-ascii 20)
  }
)

(define-map renewal-requests
  { request-id: uint }
  {
    profile-id: uint,
    requester: principal,
    requested-at: uint,
    status: (string-ascii 20),
    processed-at: (optional uint),
    processed-by: (optional principal),
    new-expiry-block: (optional uint)
  }
)

(define-data-var renewal-request-counter uint u0)

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
      (expiry-block (+ current-block (var-get default-profile-validity-period)))
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
    
    (map-set profile-expiration
      { profile-id: profile-id }
      {
        expiry-block: expiry-block,
        renewal-count: u0,
        last-renewal-block: u0,
        auto-renewal-enabled: false,
        status: "active"
      }
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

(define-private (calculate-reputation-score (profile-id uint))
  (let
    (
      (profile (map-get? kyc-profiles { profile-id: profile-id }))
      (current-reputation (default-to { base-score: u0, verification-bonus: u0, endorsement-score: u0, time-penalty: u0, last-updated: u0, total-score: u0 } (map-get? profile-reputation { profile-id: profile-id })))
      (endorsement-data (default-to { total-endorsements: u0, weighted-endorsement-score: u0, last-endorsement: u0 } (map-get? endorsement-summary { profile-id: profile-id })))
      (current-time stacks-block-height)
    )
    (match profile
      prof-data (let
        (
          (base-score (if (is-eq (get status prof-data) "verified") u100 u0))
          (verification-bonus (* (get verification-level prof-data) u20))
          (time-since-verification (if (> (get verified-at prof-data) u0) (- current-time (get verified-at prof-data)) u0))
          (time-penalty (/ (* time-since-verification (var-get reputation-decay-rate)) u1000))
          (endorsement-score (get weighted-endorsement-score endorsement-data))
          (total-score (if (> (+ base-score verification-bonus endorsement-score) time-penalty) (- (+ base-score verification-bonus endorsement-score) time-penalty) u0))
        )
        {
          base-score: base-score,
          verification-bonus: verification-bonus,
          endorsement-score: endorsement-score,
          time-penalty: time-penalty,
          last-updated: current-time,
          total-score: total-score
        }
      )
      { base-score: u0, verification-bonus: u0, endorsement-score: u0, time-penalty: u0, last-updated: current-time, total-score: u0 }
    )
  )
)

(define-public (update-profile-reputation (profile-id uint))
  (let
    (
      (new-reputation (calculate-reputation-score profile-id))
    )
    (asserts! (is-some (map-get? kyc-profiles { profile-id: profile-id })) ERR_PROFILE_NOT_FOUND)
    
    (map-set profile-reputation
      { profile-id: profile-id }
      new-reputation
    )
    (ok (get total-score new-reputation))
  )
)

(define-public (endorse-profile (endorsed-profile-id uint) (endorsement-type (string-ascii 32)))
  (let
    (
      (endorser-profile-data (map-get? user-profiles { user: tx-sender }))
      (endorsed-profile (map-get? kyc-profiles { profile-id: endorsed-profile-id }))
      (endorsement-id (+ (var-get endorsement-counter) u1))
    )
    (asserts! (is-some endorsed-profile) ERR_PROFILE_NOT_FOUND)
    (asserts! (is-some endorser-profile-data) ERR_PROFILE_NOT_FOUND)
    
    (let
      (
        (endorser-profile-id (get profile-id (unwrap-panic endorser-profile-data)))
        (endorser-reputation (map-get? profile-reputation { profile-id: endorser-profile-id }))
      )
      (asserts! (not (is-eq endorser-profile-id endorsed-profile-id)) ERR_SELF_ENDORSEMENT)
      (asserts! (is-none (map-get? profile-endorsements { endorsement-id: endorsement-id })) ERR_ENDORSEMENT_EXISTS)
      
      (let
        (
          (endorsement-weight (if (is-some endorser-reputation) (/ (get total-score (unwrap-panic endorser-reputation)) u10) u5))
          (current-summary (default-to { total-endorsements: u0, weighted-endorsement-score: u0, last-endorsement: u0 } (map-get? endorsement-summary { profile-id: endorsed-profile-id })))
        )
        (map-set profile-endorsements
          { endorsement-id: endorsement-id }
          {
            endorser-profile: endorser-profile-id,
            endorsed-profile: endorsed-profile-id,
            endorsement-weight: endorsement-weight,
            endorsement-type: endorsement-type,
            created-at: stacks-block-height,
            active: true
          }
        )
        
        (map-set endorsement-summary
          { profile-id: endorsed-profile-id }
          {
            total-endorsements: (+ (get total-endorsements current-summary) u1),
            weighted-endorsement-score: (+ (get weighted-endorsement-score current-summary) endorsement-weight),
            last-endorsement: stacks-block-height
          }
        )
        
        (var-set endorsement-counter endorsement-id)
        (unwrap-panic (update-profile-reputation endorsed-profile-id))
        (ok endorsement-id)
      )
    )
  )
)

(define-public (set-reputation-threshold (threshold-name (string-ascii 32)) (min-score uint) (description (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> min-score u0) ERR_INVALID_REPUTATION_SCORE)
    
    (map-set reputation-thresholds
      { threshold-name: threshold-name }
      {
        min-score: min-score,
        description: description
      }
    )
    (ok true)
  )
)

(define-public (update-verifier-reputation (verifier principal) (verification-successful bool))
  (let
    (
      (current-rep (default-to { total-verifications: u0, successful-verifications: u0, reputation-weight: u100, last-activity: u0 } (map-get? verifier-reputation { verifier: verifier })))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender verifier)) ERR_NOT_AUTHORIZED)
    
    (map-set verifier-reputation
      { verifier: verifier }
      {
        total-verifications: (+ (get total-verifications current-rep) u1),
        successful-verifications: (if verification-successful (+ (get successful-verifications current-rep) u1) (get successful-verifications current-rep)),
        reputation-weight: (if verification-successful (if (> (+ (get reputation-weight current-rep) u5) u200) u200 (+ (get reputation-weight current-rep) u5)) (if (< (- (get reputation-weight current-rep) u10) u50) u50 (- (get reputation-weight current-rep) u10))),
        last-activity: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-read-only (get-profile-reputation (profile-id uint))
  (map-get? profile-reputation { profile-id: profile-id })
)

(define-read-only (get-verifier-reputation (verifier principal))
  (map-get? verifier-reputation { verifier: verifier })
)

(define-read-only (get-endorsement-summary (profile-id uint))
  (map-get? endorsement-summary { profile-id: profile-id })
)

(define-read-only (get-endorsement-details (endorsement-id uint))
  (map-get? profile-endorsements { endorsement-id: endorsement-id })
)

(define-read-only (get-reputation-threshold (threshold-name (string-ascii 32)))
  (map-get? reputation-thresholds { threshold-name: threshold-name })
)

(define-read-only (meets-reputation-threshold (profile-id uint) (threshold-name (string-ascii 32)))
  (let
    (
      (reputation (map-get? profile-reputation { profile-id: profile-id }))
      (threshold (map-get? reputation-thresholds { threshold-name: threshold-name }))
    )
    (and
      (is-some reputation)
      (is-some threshold)
      (>= (get total-score (unwrap-panic reputation)) (get min-score (unwrap-panic threshold)))
    )
  )
)

(define-read-only (calculate-trust-score (profile-id uint))
  (let
    (
      (reputation (map-get? profile-reputation { profile-id: profile-id }))
      (profile (map-get? kyc-profiles { profile-id: profile-id }))
    )
    (match reputation
      rep-data (match profile
        prof-data (let
          (
            (verifier-rep (map-get? verifier-reputation { verifier: (get verifier prof-data) }))
            (verifier-weight (if (is-some verifier-rep) (get reputation-weight (unwrap-panic verifier-rep)) u100))
            (weighted-score (/ (* (get total-score rep-data) verifier-weight) u100))
          )
          weighted-score
        )
        u0
      )
      u0
    )
  )
)

;; =====================================
;; PROFILE EXPIRATION & RENEWAL SYSTEM
;; =====================================

(define-public (request-profile-renewal (profile-id uint))
  (let
    (
      (profile (unwrap! (map-get? kyc-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
      (expiration (map-get? profile-expiration { profile-id: profile-id }))
      (request-id (+ (var-get renewal-request-counter) u1))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get owner profile)) ERR_NOT_AUTHORIZED)
    (asserts! (is-some expiration) ERR_PROFILE_NOT_FOUND)
    
    (let
      (
        (exp-data (unwrap-panic expiration))
        (grace-period-end (+ (get expiry-block exp-data) (var-get renewal-grace-period)))
      )
      (asserts! (or
        (>= current-block (get expiry-block exp-data))
        (>= current-block (- (get expiry-block exp-data) u2880))) ERR_NOT_RENEWABLE) ;; Allow renewal 2 days before expiry
      (asserts! (<= current-block grace-period-end) ERR_PROFILE_EXPIRED)
      
      (map-set renewal-requests
        { request-id: request-id }
        {
          profile-id: profile-id,
          requester: tx-sender,
          requested-at: current-block,
          status: "pending",
          processed-at: none,
          processed-by: none,
          new-expiry-block: none
        }
      )
      
      (var-set renewal-request-counter request-id)
      (unwrap-panic (record-history-entry profile-id "renewal-requested" "status" (some "active") (some "renewal-pending") none))
      (ok request-id)
    )
  )
)

(define-public (approve-profile-renewal (request-id uint))
  (let
    (
      (renewal-request (unwrap! (map-get? renewal-requests { request-id: request-id }) ERR_RENEWAL_NOT_FOUND))
      (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR_VERIFIER_NOT_AUTHORIZED))
      (profile-id (get profile-id renewal-request))
      (profile (unwrap! (map-get? kyc-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
      (expiration (unwrap! (map-get? profile-expiration { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (get authorized verifier-info) ERR_VERIFIER_NOT_AUTHORIZED)
    (asserts! (is-eq (get status renewal-request) "pending") ERR_INVALID_DATA)
    
    (let
      (
        (new-expiry-block (+ current-block (var-get default-profile-validity-period)))
        (grace-period-end (+ (get expiry-block expiration) (var-get renewal-grace-period)))
      )
      (asserts! (<= current-block grace-period-end) ERR_PROFILE_EXPIRED)
      
      (map-set renewal-requests
        { request-id: request-id }
        (merge renewal-request {
          status: "approved",
          processed-at: (some current-block),
          processed-by: (some tx-sender),
          new-expiry-block: (some new-expiry-block)
        })
      )
      
      (map-set profile-expiration
        { profile-id: profile-id }
        (merge expiration {
          expiry-block: new-expiry-block,
          renewal-count: (+ (get renewal-count expiration) u1),
          last-renewal-block: current-block,
          status: "active"
        })
      )
      
      (var-set total-renewals (+ (var-get total-renewals) u1))
      (unwrap-panic (record-history-entry profile-id "profile-renewed" "expiry-block" 
        (some (int-to-ascii (to-int (get expiry-block expiration))))
        (some (int-to-ascii (to-int new-expiry-block)))
        (some (concat "renewal-" (int-to-ascii (to-int request-id))))))
      (ok true)
    )
  )
)

(define-public (reject-profile-renewal (request-id uint) (reason (string-ascii 128)))
  (let
    (
      (renewal-request (unwrap! (map-get? renewal-requests { request-id: request-id }) ERR_RENEWAL_NOT_FOUND))
      (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR_VERIFIER_NOT_AUTHORIZED))
    )
    (asserts! (get authorized verifier-info) ERR_VERIFIER_NOT_AUTHORIZED)
    (asserts! (is-eq (get status renewal-request) "pending") ERR_INVALID_DATA)
    
    (map-set renewal-requests
      { request-id: request-id }
      (merge renewal-request {
        status: "rejected",
        processed-at: (some stacks-block-height),
        processed-by: (some tx-sender)
      })
    )
    
    (unwrap-panic (record-history-entry (get profile-id renewal-request) "renewal-rejected" "status" 
      (some "renewal-pending") (some "renewal-rejected") (some reason)))
    (ok true)
  )
)

(define-public (expire-profile (profile-id uint))
  (let
    (
      (profile (unwrap! (map-get? kyc-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
      (expiration (unwrap! (map-get? profile-expiration { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
      (current-block stacks-block-height)
      (grace-period-end (+ (get expiry-block expiration) (var-get renewal-grace-period)))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get verifier profile))) ERR_NOT_AUTHORIZED)
    (asserts! (> current-block grace-period-end) ERR_NOT_RENEWABLE)
    (asserts! (not (is-eq (get status expiration) "expired")) ERR_PROFILE_EXPIRED)
    
    (map-set kyc-profiles
      { profile-id: profile-id }
      (merge profile {
        status: "expired",
        updated-at: current-block
      })
    )
    
    (map-set profile-expiration
      { profile-id: profile-id }
      (merge expiration {
        status: "expired"
      })
    )
    
    (unwrap-panic (record-history-entry profile-id "profile-expired" "status" 
      (some (get status profile)) (some "expired") none))
    (ok true)
  )
)

(define-public (set-auto-renewal (profile-id uint) (enabled bool))
  (let
    (
      (profile (unwrap! (map-get? kyc-profiles { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
      (expiration (unwrap! (map-get? profile-expiration { profile-id: profile-id }) ERR_PROFILE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner profile)) ERR_NOT_AUTHORIZED)
    
    (map-set profile-expiration
      { profile-id: profile-id }
      (merge expiration {
        auto-renewal-enabled: enabled
      })
    )
    (ok true)
  )
)

(define-public (update-validity-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_DATA)
    (asserts! (<= new-period u105120) ERR_INVALID_DATA) ;; Max 2 years
    
    (var-set default-profile-validity-period new-period)
    (ok true)
  )
)

(define-public (update-grace-period (new-grace-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> new-grace-period u0) ERR_INVALID_DATA)
    (asserts! (<= new-grace-period u10080) ERR_INVALID_DATA) ;; Max 1 week
    
    (var-set renewal-grace-period new-grace-period)
    (ok true)
  )
)

;; =====================================
;; READ-ONLY FUNCTIONS FOR RENEWAL SYSTEM
;; =====================================

(define-read-only (get-profile-expiration (profile-id uint))
  (map-get? profile-expiration { profile-id: profile-id })
)

(define-read-only (get-renewal-request (request-id uint))
  (map-get? renewal-requests { request-id: request-id })
)

(define-read-only (is-profile-expired (profile-id uint))
  (match (map-get? profile-expiration { profile-id: profile-id })
    expiration (> stacks-block-height (get expiry-block expiration))
    false
  )
)

(define-read-only (is-profile-in-grace-period (profile-id uint))
  (match (map-get? profile-expiration { profile-id: profile-id })
    expiration (let
      (
        (current-block stacks-block-height)
        (expiry-block (get expiry-block expiration))
        (grace-period-end (+ expiry-block (var-get renewal-grace-period)))
      )
      (and (> current-block expiry-block) (<= current-block grace-period-end))
    )
    false
  )
)

(define-read-only (is-profile-renewable (profile-id uint))
  (match (map-get? profile-expiration { profile-id: profile-id })
    expiration (let
      (
        (current-block stacks-block-height)
        (expiry-block (get expiry-block expiration))
        (renewal-window-start (- expiry-block u2880)) ;; 2 days before expiry
        (grace-period-end (+ expiry-block (var-get renewal-grace-period)))
      )
      (and 
        (>= current-block renewal-window-start)
        (<= current-block grace-period-end)
      )
    )
    false
  )
)

(define-read-only (get-renewal-statistics)
  {
    total-renewals: (var-get total-renewals),
    renewal-request-counter: (var-get renewal-request-counter),
    default-validity-period: (var-get default-profile-validity-period),
    grace-period: (var-get renewal-grace-period)
  }
)

(define-read-only (get-profile-renewal-history (profile-id uint))
  (match (map-get? profile-expiration { profile-id: profile-id })
    expiration (some {
      renewal-count: (get renewal-count expiration),
      last-renewal-block: (get last-renewal-block expiration),
      current-expiry: (get expiry-block expiration),
      auto-renewal-enabled: (get auto-renewal-enabled expiration),
      status: (get status expiration)
    })
    none
  )
)
