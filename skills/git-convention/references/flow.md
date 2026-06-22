# Git Flow Reference

## Branch Naming

Use:

```text
{type}/{JIRA-ISSUE-CODE}-{short-description}
```

Allowed `type` values:
- `feature`
- `hotfix`
- `refactor`
- `docs`

## Commit Format

For non-library repos use:

```text
{JIRA-ISSUE-CODE}: {verb-led description}

{optional extended description}
```

Guidance:
- keep the first line short
- start the description with a verb
- include the extended body only when it adds value

## Staging Flow

- `master` and `staging` are the two main branches.
- Work branches are created from `master`.
- Test changes via merge into `staging`.
- Fix issues in the same work branch and re-merge into `staging`.
- Before final merge, update the work branch from current `master` and resolve conflicts locally.
- Merge the work branch into `master` only after staging validation.
- Delete the work branch after successful merge.
