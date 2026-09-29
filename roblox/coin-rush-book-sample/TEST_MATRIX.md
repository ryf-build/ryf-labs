# Coin Rush Test Matrix

このMatrixは「コードがある」ではなく「挙動を確認した」をRelease条件にするためのものです。

| ID | Test | Procedure | Expected |
| --- | --- | --- | --- |
| T01 | New profile | 新規Test accountでJoin | default profile、Zone1 unlocked、Kickされない |
| T02 | Existing profile | Coins/Upgrade後にSave→Rejoin | Coins/Upgrade/Zoneが復元 |
| T03 | Load failure | Test用にDataStore accessを失敗させる | empty profileで続行せずfail closed |
| T04 | Session conflict | 同じUser profileを重複Session相当でclaim | 後発Sessionが通常Playへ入らない |
| T05 | Stale revision | 新revision保存後、古いsnapshot保存を試す | `stale_revision`で拒否 |
| T06 | Save overlap | Autosave中にexit相当Save | 同一PlayerのSnapshot capture/writeが直列化 |
| T07 | Coin double touch | 2 Clientで同じCoinを同時取得 | 仕様どおり1回のみ付与 |
| T08 | Coin respawn | Coin取得後待つ | `RespawnSeconds`後に再取得可能 |
| T09 | Magnet | Magnet Lv1+でCoinへ近づく | Server計算range内のみ取得 |
| T10 | Zone prerequisite | Zone1のみでZone3 request | reject |
| T11 | Zone unlock | 必要CoinsでZone2解除 | Coins減少 + state解放 + gate通過 |
| T12 | Invalid Remote | Table/未知ID/連打を送る | ErrorでServerを落とさずreject/rate limit |
| T13 | Receipt duplicate | 同じPurchaseIdを2回処理するTest harness | Benefitは1回だけ |
| T14 | Receipt save failure | Benefit反映後のSaveを失敗させる | `NotProcessedYet`; retryで二重付与せず保存 |
| T15 | Receipt acknowledged | Save成功後同じReceipt再配送 | `PurchaseGranted`; balance二重増加なし |
| T16 | Dynamic price | Managed Pricing対象ProductをCustom UI表示 | PromptとUIの価格が一致 |
| T17 | Pass refresh | Pass購入後Prompt close | Server ownership再確認後Attribute更新 |
| T18 | Mobile | Phone相当Viewport | UI操作可能、Core Loopを完了できる |
| T19 | Shutdown | 複数Player状態でServer close | Final saveがbounded time内で試行される |
| T20 | Analytics failure | Analytics callを失敗させる | Core gameplayは継続 |

## Receipt Testの注意

`ProcessReceipt`の本物の再配送やBackend acknowledgementは、Creator Hubで作成したTest用Developer ProductとRoblox Studio / Test環境が必要です。単体Testだけで「本番決済PASS」と判定しません。

## Evidence

Release Candidateごとに最低限残します。

```text
release id
place version
Studio version
Test ID
PASS / FAIL
observed output
screenshot/log reference
known limitation
```
