;; Service Provider Verification Contract
;; Validates and manages temporal service providers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_EXISTS (err u101))
(define-constant ERR_PROVIDER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_RATING (err u103))

(define-map providers
  { provider: principal }
  {
    verified: bool,
    reputation-score: uint,
    services-completed: uint,
    temporal-clearance: uint,
    registration-block: uint
  }
)

(define-map provider-services
  { provider: principal, service-id: uint }
  {
    service-type: (string-ascii 50),
    time-cost: uint,
    active: bool
  }
)

(define-data-var next-service-id uint u1)

;; Register a new temporal service provider
(define-public (register-provider (provider principal) (temporal-clearance uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? providers { provider: provider })) ERR_PROVIDER_EXISTS)
    (map-set providers
      { provider: provider }
      {
        verified: true,
        reputation-score: u100,
        services-completed: u0,
        temporal-clearance: temporal-clearance,
        registration-block: block-height
      }
    )
    (ok true)
  )
)

;; Add a service offering for a provider
(define-public (add-service (service-type (string-ascii 50)) (time-cost uint))
  (let ((service-id (var-get next-service-id)))
    (asserts! (is-some (map-get? providers { provider: tx-sender })) ERR_PROVIDER_NOT_FOUND)
    (map-set provider-services
      { provider: tx-sender, service-id: service-id }
      {
        service-type: service-type,
        time-cost: time-cost,
        active: true
      }
    )
    (var-set next-service-id (+ service-id u1))
    (ok service-id)
  )
)

;; Update provider reputation after service completion
(define-public (update-reputation (provider principal) (rating uint))
  (let ((provider-data (unwrap! (map-get? providers { provider: provider }) ERR_PROVIDER_NOT_FOUND)))
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (map-set providers
      { provider: provider }
      (merge provider-data {
        reputation-score: (/ (+ (* (get reputation-score provider-data) (get services-completed provider-data)) (* rating u20)) (+ (get services-completed provider-data) u1)),
        services-completed: (+ (get services-completed provider-data) u1)
      })
    )
    (ok true)
  )
)

;; Get provider information
(define-read-only (get-provider (provider principal))
  (map-get? providers { provider: provider })
)

;; Get service information
(define-read-only (get-service (provider principal) (service-id uint))
  (map-get? provider-services { provider: provider, service-id: service-id })
)
