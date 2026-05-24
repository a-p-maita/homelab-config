Mailserver scaffold (docker-mailserver)
=====================================

This folder contains a minimal scaffold for running a self-hosted mailserver
using `docker-mailserver`. It's intended for homelab use; production mail
requires attention to DNS (MX/SPF/DKIM/DMARC), PTR records, and deliverability.

Quick start
-----------

1. Copy the example env: `cp backups/secrets/mailserver.env.example backups/secrets/mailserver.env`
2. Edit `backups/secrets/mailserver.env` and set `MAIL_DOMAIN` and `POSTMASTER_ADDRESS`.
3. Generate DKIM keys:

   ./scripts/mail/generate_dkim_keys.sh mail your-domain.com

   This writes keys to `backups/secrets/mail/dkim/` and prints the TXT record for
   your DNS provider.

4. Start the mailserver (runs on ports 25/587):

   docker compose -f stacks/mail/compose.yaml up -d

5. Create mail accounts and apply configuration per docker-mailserver docs:
   <https://github.com/docker-mailserver/docker-mailserver>

Notes & recommendations
-----------------------

- Running a public mailserver from residential IPs often results in poor
  deliverability. Use a VPS relay or a reputable relay if you need reliable
  outbound mail delivery to arbitrary recipients.
- If you only need Authelia to send registration / 2FA emails during onboarding
  and testing, leaving `AUTHELIA_NOTIFIER_DISABLE_STARTUP_CHECK=true` is safe
  until the mailserver is fully configured.
- When ready, move SMTP credentials into Docker secrets and update
  `AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE` to point to `/run/secrets/authelia-smtp-password`.
