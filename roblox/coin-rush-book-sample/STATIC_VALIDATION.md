# Sample Code Static Validation

This is a repository-level static contract check, not a Roblox Studio compiler or runtime test.

- Checks: **74**
- Passed: **74**
- Failed: **0**

## Results

- [x] `required:default.project.json`
- [x] `required:ReplicatedStorage/Shared/ProductDefinitions.luau`
- [x] `required:ReplicatedStorage/Shared/UpgradeDefinitions.luau`
- [x] `required:ReplicatedStorage/Shared/ZoneDefinitions.luau`
- [x] `required:ServerScriptService/Bootstrap.server.luau`
- [x] `required:ServerScriptService/Services/DataService.luau`
- [x] `required:ServerScriptService/Services/PersistenceService.luau`
- [x] `required:ServerScriptService/Services/PlayerStateService.luau`
- [x] `required:ServerScriptService/Services/CoinService.luau`
- [x] `required:ServerScriptService/Services/MagnetService.luau`
- [x] `required:ServerScriptService/Services/ZoneGateService.luau`
- [x] `required:ServerScriptService/Services/MonetizationService.luau`
- [x] `required:ServerScriptService/Services/DemoWorldService.luau`
- [x] `required:StarterPlayer/StarterPlayerScripts/Controllers/UIController.client.luau`
- [x] `rojo_project_json`
- [x] `single_ProcessReceipt_owner`
- [x] `receipt_idempotency_marker`
- [x] `receipt_durable_before_ack`
- [x] `receipt_retry_on_failure`
- [x] `server_pass_ownership_check`
- [x] `dynamic_client_price`
- [x] `responsive_scroll_ui`
- [x] `same_key_serialization`
- [x] `session_lease`
- [x] `stale_revision_reject`
- [x] `persistence_gate`
- [x] `persistence_lock_cleanup`
- [x] `freeze_before_final_save`
- [x] `coin_not_destroyed`
- [x] `coin_respawn`
- [x] `magnet_effect_implemented`
- [x] `zone_remote_present`
- [x] `state_snapshot_request_present`
- [x] `client_does_not_send_price`
- [x] `load_failure_not_defaulted`
- [x] `autosave_jitter`
- [x] `analytics_custom_event`
- [x] `analytics_economy_event`
- [x] `analytics_onboarding_event`
- [x] `strict_mode_core`

Core Luau files are also checked for conflict markers and balanced delimiters.

## Still required

- Roblox Studio / Luau parser verification
- Multi-client Play Test
- DataStore failure/session takeover test in a published test Experience
- Developer Product receipt redelivery using a real test product
- Mobile device and network-condition verification
