;; Temporal Exchange Contract
;; Facilitates time-based service trading

(define-constant ERR_INVALID_EXCHANGE (err u300))
(define-constant ERR_EXCHANGE_NOT_FOUND (err u301))
(define-constant ERR_UNAUTHORIZED (err u302))
(define-constant ERR_EXCHANGE_EXPIRED (err u303))
(define-constant ERR_EXCHANGE_COMPLETED (err u304))

(define-map exchanges
  { exchange-id: uint }
  {
    provider: principal,
    client: principal,
    service-type: (string-ascii 50),
    time-cost: uint,
    created-at: uint,
    expires-at: uint,
    status: (string-ascii 20), ;; "pending", "active", "completed", "cancelled"
    temporal-lock: bool
  }
)

(define-map exchange-timeline
  { exchange-id: uint, event-id: uint }
  {
    event-type: (string-ascii 30),
    timestamp: uint,
    actor: principal
  }
)

(define-data-var next-exchange-id uint u1)
(define-data-var next-event-id uint u1)

;; Create a new temporal service exchange
(define-public (create-exchange
  (provider principal)
  (service-type (string-ascii 50))
  (time-cost uint)
  (duration uint)
)
  (let ((exchange-id (var-get next-exchange-id)))
    (asserts! (> time-cost u0) ERR_INVALID_EXCHANGE)
    (asserts! (> duration u0) ERR_INVALID_EXCHANGE)

    (map-set exchanges
      { exchange-id: exchange-id }
      {
        provider: provider,
        client: tx-sender,
        service-type: service-type,
        time-cost: time-cost,
        created-at: block-height,
        expires-at: (+ block-height duration),
        status: "pending",
        temporal-lock: false
      }
    )

    ;; Record creation event
    (map-set exchange-timeline
      { exchange-id: exchange-id, event-id: (var-get next-event-id) }
      {
        event-type: "exchange-created",
        timestamp: block-height,
        actor: tx-sender
      }
    )

    (var-set next-exchange-id (+ exchange-id u1))
    (var-set next-event-id (+ (var-get next-event-id) u1))
    (ok exchange-id)
  )
)

;; Accept an exchange (provider accepts)
(define-public (accept-exchange (exchange-id uint))
  (let ((exchange (unwrap! (map-get? exchanges { exchange-id: exchange-id }) ERR_EXCHANGE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get provider exchange)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status exchange) "pending") ERR_INVALID_EXCHANGE)
    (asserts! (< block-height (get expires-at exchange)) ERR_EXCHANGE_EXPIRED)

    (map-set exchanges
      { exchange-id: exchange-id }
      (merge exchange { status: "active", temporal-lock: true })
    )

    ;; Record acceptance event
    (map-set exchange-timeline
      { exchange-id: exchange-id, event-id: (var-get next-event-id) }
      {
        event-type: "exchange-accepted",
        timestamp: block-height,
        actor: tx-sender
      }
    )

    (var-set next-event-id (+ (var-get next-event-id) u1))
    (ok true)
  )
)

;; Complete an exchange
(define-public (complete-exchange (exchange-id uint))
  (let ((exchange (unwrap! (map-get? exchanges { exchange-id: exchange-id }) ERR_EXCHANGE_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get provider exchange)) (is-eq tx-sender (get client exchange))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status exchange) "active") ERR_INVALID_EXCHANGE)

    (map-set exchanges
      { exchange-id: exchange-id }
      (merge exchange { status: "completed", temporal-lock: false })
    )

    ;; Record completion event
    (map-set exchange-timeline
      { exchange-id: exchange-id, event-id: (var-get next-event-id) }
      {
        event-type: "exchange-completed",
        timestamp: block-height,
        actor: tx-sender
      }
    )

    (var-set next-event-id (+ (var-get next-event-id) u1))
    (ok true)
  )
)

;; Cancel an exchange
(define-public (cancel-exchange (exchange-id uint))
  (let ((exchange (unwrap! (map-get? exchanges { exchange-id: exchange-id }) ERR_EXCHANGE_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender (get provider exchange)) (is-eq tx-sender (get client exchange))) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq (get status exchange) "completed")) ERR_EXCHANGE_COMPLETED)

    (map-set exchanges
      { exchange-id: exchange-id }
      (merge exchange { status: "cancelled", temporal-lock: false })
    )

    ;; Record cancellation event
    (map-set exchange-timeline
      { exchange-id: exchange-id, event-id: (var-get next-event-id) }
      {
        event-type: "exchange-cancelled",
        timestamp: block-height,
        actor: tx-sender
      }
    )

    (var-set next-event-id (+ (var-get next-event-id) u1))
    (ok true)
  )
)

;; Get exchange details
(define-read-only (get-exchange (exchange-id uint))
  (map-get? exchanges { exchange-id: exchange-id })
)

;; Get exchange timeline event
(define-read-only (get-timeline-event (exchange-id uint) (event-id uint))
  (map-get? exchange-timeline { exchange-id: exchange-id, event-id: event-id })
)
