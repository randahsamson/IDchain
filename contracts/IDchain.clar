(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROFILE_EXISTS (err u101))
(define-constant ERR_PROFILE_NOT_FOUND (err u102))
(define-constant ERR_INVALID_VERIFICATION_LEVEL (err u103))
(define-constant ERR_INSUFFICIENT_VERIFICATION (err u104))
(define-constant ERR_VERIFIER_NOT_AUTHORIZED (err u105))
(define-constant ERR_PROFILE_SUSPENDED (err u106))
(define-constant ERR_INVALID_DATA (err u107))

(define-data-var profile-counter uint u0)
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