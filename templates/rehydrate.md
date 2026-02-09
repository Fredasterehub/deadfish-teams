# Rehydrate Runbook (/resume)

## 1) Locate latest track
- [ ] `latest_track="$(ls -1d tracks/*/ 2>/dev/null | sort | tail -n 1)"`
- [ ] If empty: `python3 bin/new-track.py --slug <track-slug> --track-name "<Track Name>"`
- [ ] If set: `echo "$latest_track"`

## 2) Open canonical files
- [ ] `index.md`
- [ ] `spec.md`
- [ ] `plan.md`
- [ ] `notes.md`
- [ ] Latest files under `task-packets/`, `verdicts/`, `snapshots/`

## 3) Recreate teammates (if missing)
- [ ] Re-spawn teammates using `CLAUDE.md` kickoff contract.
- [ ] Restore `CLAUDE_CODE_TASK_LIST_ID` before delegating.

## 4) Reconcile plan vs task list
- [ ] Treat `plan.md` order as canonical execution order.
- [ ] Reconcile plan checkboxes against native Claude task statuses.
- [ ] If packet files are missing/stale: `python3 bin/plan-to-packets.py "${latest_track%/}/plan.md" --overwrite`
- [ ] For execution prompts: `python3 bin/packet-to-task.py <packet_path>`

## 5) Resolve out-of-sync states
- [ ] verify.sh PASS but plan unchecked: check it and log evidence in `notes.md`.
- [ ] Task marked done but verify.sh FAIL: reopen task and append failure evidence.
- [ ] Packet intent drift: update `plan.md` first, then rerun `bin/plan-to-packets.py --overwrite`.
- [ ] 2+ failed attempts on same task: request conductor boundary decision.
