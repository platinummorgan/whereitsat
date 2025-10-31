# Manual QA Checklist

## Core Flows
- [ ] Add item (name required, error if blank)
- [ ] Add loan (select item, person required)
- [ ] Add stash (select item, place name required)

## Reminders & Notifications
- [ ] Schedule loan reminder
- [ ] Receive notification at configured time
- [ ] Tap notification deep-links to item detail

## Item/Loan/Stash Actions
- [ ] Mark loan returned (with photo)
- [ ] Mark stash found

## Search
- [ ] Search by person
- [ ] Search by place
- [ ] Search by tag

## Export & Share
- [ ] Export CSV and PDF
- [ ] Share via system sheet

## App Lock
- [ ] Enable App Lock
- [ ] Verify lock on cold start
- [ ] Verify lock after 2 minutes in background
- [ ] Verify Face/PIN fallback

## Permissions
- [ ] Deny camera/storage/media permissions
- [ ] Confirm actionable snackbar fallback

## Accessibility
- [ ] Large tap targets
- [ ] Semantic labels
- [ ] Dynamic text sizing
- [ ] Haptic feedback on save/return

## Release Build
- [ ] Build signed/unsigned release APK
- [ ] Place APK in /builds with versioned name
- [ ] Document keystore signing steps in README
