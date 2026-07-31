# Secrets (gitignored)

Put the Firebase service account JSON here as:

```text
secrets/firebase-service-account.json
```

Never commit this file. Docker Compose mounts `./secrets` read-only into
`core-backend` as `/secrets` (`FCM_SERVICE_ACCOUNT_FILE`).

See [`docs/fcm-setup.md`](../docs/fcm-setup.md).
