;; Project Verification Contract
;; Validates legitimate film productions

(define-data-var contract-owner principal tx-sender)

;; Project status: 0 = pending, 1 = verified, 2 = rejected
(define-map projects
  { project-id: uint }
  {
    owner: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    budget: uint,
    start-date: uint,
    end-date: uint,
    status: uint,
    verification-date: (optional uint)
  }
)

;; List of authorized verifiers
(define-map authorized-verifiers principal bool)

;; Events
(define-public (register-project (project-id uint) (title (string-utf8 100)) (description (string-utf8 500)) (budget uint) (start-date uint) (end-date uint))
  (let
    ((project-exists (is-some (map-get? projects { project-id: project-id }))))
    (asserts! (not project-exists) (err u1)) ;; Project ID already exists
    (asserts! (> end-date start-date) (err u2)) ;; End date must be after start date
    (asserts! (> budget u0) (err u3)) ;; Budget must be greater than 0

    (map-set projects
      { project-id: project-id }
      {
        owner: tx-sender,
        title: title,
        description: description,
        budget: budget,
        start-date: start-date,
        end-date: end-date,
        status: u0, ;; pending
        verification-date: none
      }
    )
    (ok true)
  )
)

(define-public (verify-project (project-id uint) (approve bool) (timestamp uint))
  (let
    ((project (unwrap! (map-get? projects { project-id: project-id }) (err u4))) ;; Project not found
     (is-verifier (default-to false (map-get? authorized-verifiers tx-sender))))

    (asserts! is-verifier (err u5)) ;; Not authorized to verify
    (asserts! (is-eq (get status project) u0) (err u6)) ;; Project already verified or rejected

    (map-set projects
      { project-id: project-id }
      (merge project {
        status: (if approve u1 u2), ;; 1 = verified, 2 = rejected
        verification-date: (some timestamp)
      })
    )
    (ok true)
  )
)

;; Admin functions
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u7)) ;; Not contract owner
    (map-set authorized-verifiers verifier true)
    (ok true)
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u7)) ;; Not contract owner
    (map-delete authorized-verifiers verifier)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u7)) ;; Not contract owner
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

(define-read-only (is-project-verified (project-id uint))
  (match (map-get? projects { project-id: project-id })
    project (is-eq (get status project) u1)
    false
  )
)

(define-read-only (is-verifier (address principal))
  (default-to false (map-get? authorized-verifiers address))
)

