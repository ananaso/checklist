# checklist

Create checklists to help you remember things you need to do, repeatedly

## Layout

- `lib/`: the Flutter app (Android and web).
- `packages/checklist_core/`: the data model shared by the app and the
  server: the Drift database, the `ChecklistStore` interface the app's
  screens use, and the client for the server.
- `server/`: the checklist server the web app talks to.
- `deploy/`: hosting on the home server (Caddy, Authelia login, systemd);
  see [deploy/README.md](deploy/README.md). `deploy/deploy.sh` builds and
  deploys.

On Android the app keeps its data on the phone (`flutter run`,
`flutter build apk`). On the web it calls the server, so everyone logged in
shares the same checklists, live.
