;; Talent-proof.clar
;; SkillChain: Decentralized Talent Verification System
;; A smart contract for verifying professional skills on-chain
;; Version: 1.0 (Fixed)

;; ---------- Admin (set once at deploy) ----------
(define-data-var contract-owner principal tx-sender)

;; ---------- Counters ----------
(define-data-var next-talent-id uint u1)

;; ---------- Maps ----------
;; talents: { id: uint } -> { owner: principal, name: string-ascii 40, profession: string-ascii 40, reputation: uint, registered-at: uint }
(define-map talents
  { id: uint }
  {
    owner: principal,
    name: (string-ascii 40),
    profession: (string-ascii 40),
    reputation: uint,
    registered-at: uint
  })

;; skills: { talent-id: uint, skill: (string-ascii 40) } -> { verified: bool, verifier: (optional principal), timestamp: uint }
(define-map skills
  { talent-id: uint, skill: (string-ascii 40) }
  { verified: bool, verifier: (optional principal), timestamp: uint })

;; verifiers: { verifier: principal } -> { approved: bool, added-at: uint }
(define-map verifiers
  { verifier: principal }
  { approved: bool, added-at: uint })

;; ---------- Modifiers / Helpers ----------
(define-read-only (is-owner (p principal))
  (is-eq p (var-get contract-owner))
)

(define-read-only (is-approved-verifier (p principal))
  (match (map-get? verifiers {verifier: p})
    verifier (get approved verifier)
    false
  )
)

;; ---------- Public: Admin Management of Verifiers ----------
(define-public (add-verifier (v principal))
  (begin
    (asserts! (is-owner tx-sender) (err "UNAUTHORIZED"))
    (map-set verifiers {verifier: v} {approved: true, added-at: stacks-block-height})
    (print {event: "verifier-updated", verifier: v, approved: true})
    (ok true)
  )
)

(define-public (remove-verifier (v principal))
  (begin
    (asserts! (is-owner tx-sender) (err "UNAUTHORIZED"))
    (map-set verifiers {verifier: v} {approved: false, added-at: stacks-block-height})
    (print {event: "verifier-updated", verifier: v, approved: false})
    (ok true)
  )
)

;; ---------- Public: Talent Registration ----------
(define-public (register-talent (name (string-ascii 40)) (profession (string-ascii 40)))
  (let ((id (var-get next-talent-id)))
    (begin
      (map-set talents {id: id}
        {
          owner: tx-sender,
          name: name,
          profession: profession,
          reputation: u0,
          registered-at: stacks-block-height
        })
      (var-set next-talent-id (+ id u1))
      (print {event: "talent-registered", id: id, owner: tx-sender, name: name, profession: profession})
      (ok id)
    )
  )
)

;; ---------- Public: Skill Submission (only talent owner) ----------
(define-public (submit-skill (talent-id uint) (skill (string-ascii 40)))
  (begin
    (match (map-get? talents {id: talent-id})
      talent
      (let ((owner (get owner talent)))
        (asserts! (is-eq owner tx-sender) (err "NOT_TALENT_OWNER"))
        (asserts! (is-none (map-get? skills {talent-id: talent-id, skill: skill})) (err "SKILL_ALREADY_EXISTS"))
        (map-set skills {talent-id: talent-id, skill: skill} {verified: false, verifier: none, timestamp: stacks-block-height})
        (print {event: "skill-submitted", talent-id: talent-id, skill: skill, submitter: tx-sender})
        (ok true)
      )
      (err "TALENT_NOT_FOUND")
    )
  )
)

;; ---------- Public: Verify Skill (only approved verifiers) ----------
(define-public (verify-skill (talent-id uint) (skill (string-ascii 40)))
  (begin
    (asserts! (is-approved-verifier tx-sender) (err "NOT_APPROVED_VERIFIER"))
    (match (map-get? skills {talent-id: talent-id, skill: skill})
      rec
      (let ((is-verified (get verified rec)))
        (asserts! (not is-verified) (err "ALREADY_VERIFIED"))
        ;; mark skill as verified
        (map-set skills {talent-id: talent-id, skill: skill}
                         {verified: true, verifier: (some tx-sender), timestamp: stacks-block-height})
        ;; increment talent reputation
        (match (map-get? talents {id: talent-id})
          tdata
          (begin
            (let ((old-rep (get reputation tdata)))
              (map-set talents {id: talent-id}
                {
                  owner: (get owner tdata),
                  name: (get name tdata),
                  profession: (get profession tdata),
                  reputation: (+ old-rep u1),
                  registered-at: (get registered-at tdata)
                })
            )
            (print {event: "skill-verified", talent-id: talent-id, skill: skill, verifier: tx-sender})
            (ok true)
          )
          (err "TALENT_NOT_FOUND")
        )
      )
      (err "SKILL_NOT_FOUND")
    )
  )
)

;; ---------- Public: Revoke Verification (admin or verifier) ----------
(define-public (revoke-skill (talent-id uint) (skill (string-ascii 40)))
  (begin
    (match (map-get? skills {talent-id: talent-id, skill: skill})
      rec
      (let ((mverifier (get verifier rec)) (is-verified (get verified rec)))
        (asserts! is-verified (err "NOT_VERIFIED"))
        (let ((allowed (or (is-owner tx-sender) (and (is-some mverifier) (is-eq (unwrap! mverifier (err "UNWRAP_FAIL")) tx-sender)))))
          (asserts! allowed (err "UNAUTHORIZED"))
          ;; unset verification
          (map-set skills {talent-id: talent-id, skill: skill}
                   {verified: false, verifier: none, timestamp: (get timestamp rec)})
          ;; decrement reputation (min 0)
          (match (map-get? talents {id: talent-id})
            tdata
            (let ((old-rep (get reputation tdata))
                  (new-rep (if (>= old-rep u1) (- old-rep u1) u0)))
              (map-set talents {id: talent-id}
                {
                  owner: (get owner tdata),
                  name: (get name tdata),
                  profession: (get profession tdata),
                  reputation: new-rep,
                  registered-at: (get registered-at tdata)
                })
              (ok true)
            )
            (err "TALENT_NOT_FOUND")
          )
        )
      )
      (err "SKILL_NOT_FOUND")
    )
  )
)

;; ---------- Read-only getters ----------
(define-read-only (get-talent (talent-id uint))
  (map-get? talents {id: talent-id})
)

(define-read-only (get-skill (talent-id uint) (skill (string-ascii 40)))
  (map-get? skills {talent-id: talent-id, skill: skill})
)

(define-read-only (get-talent-reputation (talent-id uint))
  (match (map-get? talents {id: talent-id})
    t (ok (get reputation t))
    (err "TALENT_NOT_FOUND")
  )
)

(define-read-only (is-verifier (addr principal))
  (match (map-get? verifiers {verifier: addr})
    v (ok (get approved v))
    (ok false)
  )
)

(define-read-only (get-next-talent-id)
  (ok (var-get next-talent-id))
)