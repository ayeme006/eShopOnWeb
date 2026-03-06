# Branching strategy for eShopOnWeb

Recommended strategy: Feature branch workflow (Gitflow-inspired).

Guidelines
- Main branch: `main` (production-ready). Only release branches merge here. Protect with branch policies.
- Develop branch: `develop` (integration branch). Feature branches merge here.
- Feature branches: `feature/<short-desc>` from develop, merge back to develop via PR.
- Release branches: `release/v1.x` from develop when ready for release, merge to main and develop.
- Hotfix branches: `hotfix/<short-desc>` from main, merge to main and develop.

PR requirements
- Create a PR from feature branch to `develop`.
- Require at least 2 reviewers for non-trivial changes.
- Require passing CI build and unit tests before merging.
- Require work item link or issue reference.

Why feature branches?
- Allows parallel development on features, better isolation, but requires discipline to avoid long-lived branches.

See `PULL_REQUEST_TEMPLATE.md` and `scripts/set-azure-devops-branch-policies.sh` for automation helpers.
