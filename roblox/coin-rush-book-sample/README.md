# Coin Rush — Roblox運営本の公開Companion

このディレクトリは、Zenn本 **「Robloxでゲームを作って、運営して、稼ぐ本」** の付属Sampleです。

本文の設計を1本につないだ **end-to-end教材実装** で、空のPlaceへ同期すると、Coinが存在しない場合はDemo Worldと基本UIを自動生成し、次の流れを確認できます。

```text
Join
→ profile claim / load
→ Coin pickup + respawn
→ Speed / Magnet upgrade
→ Zone unlock + gate enforcement
→ autosave / session lease
→ analytics events
→ Developer Product receipt (ID設定時)
→ final save / session release
```

本: https://zenn.dev/ryf/books/roblox-game-ops-monetization

> **検証状態**
>
> - Static contract QA: **74 / 74 PASS**
> - Roblox Studio / Luau parser: 実機確認が必要
> - Multi-client / Mobile / Network: 実機確認が必要
> - DataStore / Analytics / Developer Product Receipt: Published Test Experienceで確認が必要
>
> Static QAが通ったことを、Engine上のE2E PASSとは扱いません。

## 最短の起動方法

### Rojoを使う場合

`coin-rush/default.project.json` をProject rootとして同期できます。

```text
coin-rush/
├─ default.project.json
├─ ReplicatedStorage/
├─ ServerScriptService/
└─ StarterPlayer/
```

同期後にPlayすると、World内に`Coin` tagが1つも無い場合、`DemoWorldService`が最低限のFloor / Spawn / Coins / Zone Gateを生成します。UIも`UIController.client.luau`が生成するため、最初の確認に手作業のScreenGuiは不要です。

### Studioへ手動で入れる場合

Folder構造どおりにModuleScript / Script / LocalScriptを作成して内容を貼り付けます。

- `ReplicatedStorage/Shared`
- `ServerScriptService/Services`
- `ServerScriptService/Infrastructure`
- `ServerScriptService/Bootstrap.server.luau`
- `StarterPlayer/StarterPlayerScripts/Controllers/UIController.client.luau`

DataStoreをStudioから試す場合は、**Test用ExperienceでAPI access設定を確認してから**行ってください。本番ExperienceのPlayer dataを教材Testで触らないでください。

## 実装済み

### Gameplay

- Coin valueはServer側Attributeから取得
- 同じCoinの多重`Touched`をclaim lockで抑制
- 取得後にCoinをhideし、`RespawnSeconds`後に再出現
- Speed UpgradeをCharacterへ適用
- Magnet UpgradeをServer側rangeで判定し、自動取得
- Zone 2 / Zone 3をCoinsで解除
- `ZoneGate` tag + `ZoneId`で未解除Playerを戻す

### Data

- Load failureとNew Playerを分離
- `UpdateAsync`ベース
- 同一KeyのDataStore requestを直列化
- Player単位のPersistence gateでAutosave / exit / shutdownのSnapshot captureを直列化
- `revision`で古いSnapshotを拒否
- `sessionId + leaseExpiresAt`で同時Sessionを抑制
- Leaseは180秒、通常60秒ごとにrenew
- Save中に新しい変更が入っても、保存したrevisionまでしかclean扱いしない

### Monetization

`ReplicatedStorage/Shared/ProductDefinitions.luau` のIDは初期値`0`です。`0`のままなら購入Buttonを非表示にします。

Developer Productは:

```text
ProcessReceipt
→ Product allowlist
→ PurchaseId idempotency
→ Benefit + processed markerをPlayerStateへ反映
→ Profileを永続化
→ 成功時だけ PurchaseGranted
```

の順で処理します。Saveに失敗した場合は`NotProcessedYet`を返します。

PassはPrompt終了だけをAuthorityにせず、Serverから`UserOwnsGamePassAsync()`で再確認します。

### Dynamic price

Custom UIのProduct/Pass価格はClientで`GetProductInfoAsync()`を使って取得します。Managed/Regional Pricing等で、固定したRobux文字列と購入Promptがずれるのを避けます。

## Productionへ出す前に

- 最新Roblox StudioでServer + 2 ClientsをPlay Test
- DataStore API failure / load conflict / shutdownをTest
- Migration fixtureをTest
- 実Product IDでReceipt再配送・Save failureをTest
- Mobile Emulator + 実端末確認
- Creator Hubの現行Monetization / Publishing / Analytics条件確認
- Support / incident手順を用意

詳細は`TEST_MATRIX.md`と本編のRelease Gateを使ってください。

## 意図的に残している制約

- `processedPurchases`をPlayer profile内に保持する方式は、購入数が非常に多いGameでは肥大化します。大規模運営では専用Ledger / Outboxへの分離を検討してください。
- Demo WorldとProgrammatic UIは教材用です。最終Art / UXの完成形ではありません。
- RobloxのPlatform APIやMonetization条件は変更されるため、本編のReference Mapから公開直前に再確認してください。

## License

Sample code is provided under the MIT License. See `LICENSE`.
