;; Provider Verification Contract
;; This contract validates healthcare practitioners

(define-data-var contract-version uint u1)

;; Data structures
(define-map providers
  { provider-id: (string-ascii 64) }
  {
    name: (string-ascii 256),
    specialty: (string-ascii 100),
    license-number: (string-ascii 64),
    license-expiry: uint,
    is-verified: bool,
    verification-date: uint,
    verification-authority: principal
  }
)

(define-map verification-authorities principal bool)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-ALREADY-VERIFIED u101)
(define-constant ERR-PROVIDER-NOT-FOUND u102)
(define-constant ERR-INVALID-LICENSE u103)

;; Initialize contract owner
(define-data-var contract-owner principal tx-sender)

;; Read-only functions
(define-read-only (get-contract-version)
  (var-get contract-version)
)

(define-read-only (get-provider (provider-id (string-ascii 64)))
  (map-get? providers { provider-id: provider-id })
)

(define-read-only (is-verification-authority (authority principal))
  (default-to false (map-get? verification-authorities authority))
)

;; Public functions
(define-public (register-provider
    (provider-id (string-ascii 64))
    (name (string-ascii 256))
    (specialty (string-ascii 100))
    (license-number (string-ascii 64))
    (license-expiry uint)
  )
  (begin
    ;; Only allow registration if provider doesn't exist or isn't verified
    (asserts! (is-provider-unverified provider-id) (err ERR-ALREADY-VERIFIED))

    ;; Store provider information (unverified)
    (map-set providers
      { provider-id: provider-id }
      {
        name: name,
        specialty: specialty,
        license-number: license-number,
        license-expiry: license-expiry,
        is-verified: false,
        verification-date: u0,
        verification-authority: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (verify-provider (provider-id (string-ascii 64)))
  (let (
    (provider (unwrap! (get-provider provider-id) (err ERR-PROVIDER-NOT-FOUND)))
  )
    ;; Check if sender is authorized to verify
    (asserts! (is-verification-authority tx-sender) (err ERR-NOT-AUTHORIZED))

    ;; Check if license is still valid
    (asserts! (> (get license-expiry provider) block-height) (err ERR-INVALID-LICENSE))

    ;; Update provider verification status
    (map-set providers
      { provider-id: provider-id }
      (merge provider {
        is-verified: true,
        verification-date: block-height,
        verification-authority: tx-sender
      })
    )
    (ok true)
  )
)

(define-public (add-verification-authority (authority principal))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (map-set verification-authorities authority true)
    (ok true)
  )
)

(define-public (remove-verification-authority (authority principal))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (map-delete verification-authorities authority)
    (ok true)
  )
)

(define-public (update-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (upgrade-contract-version (new-version uint))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (var-set contract-version new-version)
    (ok true)
  )
)

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-provider-unverified (provider-id (string-ascii 64)))
  (let ((provider (get-provider provider-id)))
    (or
      (is-none provider)
      (not (get is-verified (default-to
        {
          name: "",
          specialty: "",
          license-number: "",
          license-expiry: u0,
          is-verified: false,
          verification-date: u0,
          verification-authority: tx-sender
        }
        provider
      )))
    )
  )
)
