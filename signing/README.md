# Signing Materials

This directory is reserved for local HarmonyOS release signing materials.

Do not commit private signing files or passwords. The directory ignore rule keeps all local files ignored except this README and `.gitignore`.

Typical local-only files include:

- `.p12` application signing certificate
- `.cer` / `.p7b` certificate files
- release profile / provisioning profile
- password or alias files

See `docs/RELEASE.md` for release build instructions.
