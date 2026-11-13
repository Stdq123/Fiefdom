# 《采邑春秋》Steam 上架清单

目标：Steam 全球发行（PC 桌面端）。Steam 为自助发行，**不要求中国游戏版号**，不区分「开放试玩 / 正式上线」，审核只做身份核验与「商店页 + 构建」的技术/合规检查，不筛选游戏品质。

依据：Valve 官方 Steamworks 文档，核对日期 **2026-11-13**。Valve 政策会变动，且部分页面口径不一致（见「时间线」），**实际可发布日与要求一律以 Steamworks 后台为准**。

图例：`- [ ]` 待办，`- [x]` 已完成。本清单只做勾选跟踪，不改动任何代码或配置。

---

## 0. 主体与资料准备（最慢，先做）

- [ ] 确定发行主体：个人（Sole Proprietorship）或公司；后续所有名称必须逐字一致
- [ ] 确定法定英文名称（个人用身份证姓名拼音，公司用营业执照英文名），**不用昵称、工作室品牌名、DBA**
- [ ] 准备身份证明文件（个人身份证正反面 / 公司营业执照）
- [ ] 开通可接收**美元电汇**的银行账户，确认 SWIFT/BIC、开户行全称与地址；**账户持有人姓名须与法定名称完全一致**（公司主体须为对公账户）
- [ ] 准备税务信息：中国主体属美国税收协定居民，走 **W-8BEN / W-8BEN-E** 路径；准备母国税号（个人身份证号 / 统一社会信用代码）作为 Foreign TIN
- [ ] 确认境内报税方式，规划 Steamworks 财报 CSV + 银行流水 + 税务表副本的证据链
- [ ] 确认游戏英文标题（现有导出预设使用 `Fiefdom`，需与商店页标题一致）
- [ ] 确认变现模式：**纯「免费 + 广告」在 Steam 不被收录**，如需免费须走 Steam 钱包内购或 F2P 授权

## 1. Steamworks 入驻

入口：`https://partner.steamgames.com/steamdirect`，用 Steam 账号登录。

- [ ] 签署 NDA 与 **Steam Distribution Agreement（SDA）**（电子签）
- [ ] 支付 **Steam Direct Fee：$100 USD / 每个产品**，不可用 Steam 钱包余额
  - 不可退款；当该产品 Steam 商店 + 内购 **Adjusted Gross Revenue ≥ $1,000** 时在后续结算中返还
  - DLC、绑定游戏的原声带不另收费；独立 Demo / 独立原声带算新产品，需再交 $100
  - 只由具备 Admin 权限的账号支付；app credit 归付款账号，发票抬头也是该账号
- [ ] 填写银行信息、税务问卷、完成身份验证
- [ ] 等待核验通过：官方称该过程 **15–30 天**，税务第三方核验最长 30 天，期间信息不可修改
- [ ] 核验通过后下载 **Steamworks SDK**（含 steamcmd 与构建脚本模板）
- [ ] 为团队成员分配权限；发布者须具备 `Publish app changes to Steam` 与 `Manage pricing and discounts` 两项权限

## 2. 创建 App

- [ ] 在 Steamworks 创建应用，记录 **App ID**
- [ ] 确认后台已生成 standard packages（缺失时在「All Associated Packages, DLC, Demos And Tools」点 Create Standard Packages）
- [ ] 设定确切的预期发布日期（后台用；前台可选显示精确日期 / 月 / 季度 / 年 / Coming Soon）
- [ ] 注意：距指定日期 **两周内不可再改发布日期**；官方不建议周末发布

## 3. 商店页（Store Presence 清单）

### 3.1 素材（官方 2024-08 更新尺寸，旧尺寸不再接受）

| 资产 | 尺寸 / 格式 | 必需 |
|---|---|---|
| Header Capsule | 920×430 | 是 |
| Small Capsule | 462×174 | 是 |
| Main Capsule | 1232×706 | 是 |
| Vertical Capsule | 748×896 | 是 |
| 截图 | ≥1920×1080，16:9 | 是 |
| Shortcut Icon | 256×256，.ico/.png | 是 |
| App Icon | 184×184，.jpg | 是 |
| Library Capsule | 600×900 | 是 |
| Library Hero | 3840×1240，.png | 是 |
| Library Logo | 1280 宽或 720 高，.png | 是 |
| Library Header Capsule | 920×430 | 是 |
| Event Cover | 800×450 | 是 |
| Page Background | 1438×810 | 否 |

- [ ] 全部胶囊图含**清晰可读**的游戏标题或 Logo
- [ ] 截图**只含实机画面**：不用概念图、预渲染过场、奖项标识、营销文案
- [ ] 制作并上传**宣传片**（Steam 发行必需项）
- [ ] 撰写英文（及需要语种）简介：详实、连贯，**不放外链**
- [ ] 商店页**只写上线时已实现的功能**；计划中的功能删除或明确标注尚未推出
- [ ] 填写系统需求、支持语言、标签、开发商/发行商信息
- [ ] 文案与游戏内文本口径一致：出海前同步处理已记录的考据问题（完整二十四节气、铜钱/金/两/贯货币单位、战国人物与典故等），避免宣传与实际内容自相矛盾

### 3.2 内容调查（Content Survey，提审前必填）

- [ ] General Content
- [ ] Mature Content
- [ ] Generative AI Content（依据 2026-01 修订口径）
  - 只披露**玩家可见/可听/可读**的 AI 生成内容（含随包美术、音乐、配音、文本、本地化，以及商店素材/宣传片素材）
  - 区分 **Pre-generated**（开发期生成并随包发布）与 **Live-generated**（运行时生成，须说明防止违法输出的护栏；运行时生成成人内容目前禁止）
  - 代码助手、调试工具、内部概念稿等效率工具**豁免**
  - 披露文字会公开展示在商店页「AI Generated Content Disclosure」，措辞具体、如实

### 3.3 Coming Soon

- [ ] 提交商店页并设为公开 **Coming Soon**，**至少公开展示 2 周**
- [ ] 期间积累愿望单、参与讨论；可报名 **Steam Next Fest**（仅未发行游戏可参加）
- [ ] 注意：成人内容标记「Adult Only Sexual Content」时，商店页与构建须同时提交后才审，耗时更长

## 4. 构建（Game Build 清单）

仓库现状：`export_presets.cfg` 只有 **Windows Desktop** 一个预设，导出 `build/Fiefdom.exe`（x86_64、未嵌入 pck、未代码签名）。

- [ ] 确认要声明的操作系统；**商店页声明的每个 OS 都必须能正常启动**（审核会逐个验证）
- [ ] 如需 macOS / Linux，新增对应导出预设并实测启动
- [ ] 在 Steamworks「General Installation Settings」定义至少一个 **Launch Option**（可执行文件路径 + 参数）
- [ ] 在 Depots 页配置 depot，按 OS / 语言分设（单平台可保持 All OSes）
- [ ] 建专用 **build 账号**，授予 `Edit App Metadata` + `Publish App Changes To Steam`
  - 给已发行游戏设 build live 的账号须绑定手机或 Steam 移动应用
  - 账号安全信息（邮箱/手机）变更后须等 **3 天**才能设 live
- [ ] 写 `.vdf` 构建脚本，用 `steamcmd +runscript` 上传到 **default 分支**（接近最终版即可，审核期间可继续更新）
- [ ] 用 beta 分支做内部/外部测试
- [ ] 打包注意：SteamPipe 按 1MB 分块做增量，pack 文件建议控制在 1–2GB，避免资产顺序重排与绝对偏移导致更新包膨胀
- [ ] 若页面列出成就/云存档/排行榜/创意工坊等功能，需在 build 中实现；内购**必须走 Steam Wallet**
- [ ] （可选）接入 Steamworks API；Godot 项目一般用 **GodotSteam**（GDExtension/模块）包装官方 C++ SDK；不接 SDK 也可上架
- [ ] （可选）Steam Deck 兼容性验证

## 5. 定价与折扣

- [ ] 设置基准价并做区域定价：支持 **37 种货币、4 个区域组**；缺某币种价格则该地区无法购买
- [ ] 遵守最低价：基准价不低于 $0.99 档，最低成交价约 $0.49
- [ ] 提交定价（初始定价与调价由 Valve 审核，通常 **1–2 个工作日**）
- [ ] 设定首发折扣（可在发布时生效）
- [ ] 记录冷却规则：发布后 **30 天内**不能提交折扣；首发折扣结束后还有 30 天；**涨价触发 30 天折扣冷却**；发布后 30 天内原则上不改价

## 6. 审核与发布（顺序不可颠倒）

- [ ] 两个清单（Store Presence / Game Build）全部完成
- [ ] 先点商店页 **Mark as ready for review**；**必须先提商店页审核，才能提构建审核**
- [ ] 预留审核时间：官方 Steam Direct 页写整体 **1–5 天**；Review Process 页写商店页 / 构建各 **3–5 个工作日**，并建议各**预留至少 7 个工作日**
- [ ] 商店页通过 → 提交构建审核 → 构建通过
- [ ] 核对审核要点：所有声明 OS 能启动、页面功能均已实现、内购走 Steam Wallet、无恶意行为
- [ ] 到允许发行日，手动点绿色 **Release App** → `Publish Now` → `Release Now`
  - 审核通过**不会自动发布**；发布同时生效首发折扣与发布时间戳
- [ ] 发布后按需更新 build（已通过审核的产品后续更新无需再审）

## 7. 发布后

- [ ] 维护社区中心、公告、愿望单转化数据
- [ ] 遵守折扣冷却期再参与促销/特卖
- [ ] 保存 Steamworks 财报 CSV、银行流水、W-8BEN 提交副本、预扣税凭证
- [ ] 按境内主体身份申报收入；已在美国被预扣的税款通常可申请抵免
- [ ] W-8BEN 有效期到期前更新，避免恢复 30% 预扣

---

## 时间线（关键约束）

| 项目 | 官方口径 |
|---|---|
| 文书 / 银行 / 税务 / 身份验证 | 15–30 天 |
| 付费到可发布 | **两处官方页面不一致**：Steam Direct 一处写 **30 天**，另一处写 **21 天**；按 **30 天**规划 |
| Coming Soon 公开 | 至少 **2 周** |
| 商店页审核 | 3–5 工作日，建议留 7 工作日 |
| 构建审核 | 3–5 工作日，建议留 7 工作日 |

三条时钟并行，取最长者。新账号从零到可发布现实最短约 **4–6 周**；建议按 **3–4 个月**排期以积累愿望单。**具体可发布日以 Steamworks 后台显示为准。**

## 费用与税务速记

- Steam Direct Fee：**$100 / 产品**，AGR ≥ $1,000 后返还，不可退款
- 平台分成：标准 Valve **30%** / 开发者 70%；收入超过 $10M、$50M 有阶梯调整（以 SDA 为准）；另有各地增值税/销售税由 Steam 代收
- 未提交有效税务表：按 **30%** 预扣；按中美税收协定提交 W-8BEN 后，第三方普遍报为 **10%**，**实际税率以 Steamworks 税务问卷核定结果为准**
- 收款：美元电汇，开户名与 Steamworks 法定名称逐字一致

## 官方明确不收录（摘要）

仇恨言论；真人裸露/色情影像；未正确标注并年龄门控的成人内容；诽谤；**无权利的内容**；违反上架地法律的内容；明显冒犯或刻意猎奇；剥削儿童；恶意软件或意外修改用户电脑；骗取 Steam 凭据/金融信息；与已发行产品无关的视频；非交互式 360° VR 视频；**区块链 / 加密货币 / NFT**；**以广告为主要商业模式的应用**。

## 常见驳回原因

- 法定名称、银行账户名、税务表姓名不一致
- 截图含概念图/预渲染/营销文案，或胶囊图标题不可读
- 商店页写了尚未实现的功能，或简介含外链
- 页面声明的 OS 上构建无法启动
- 内购未走 Steam Wallet、链到第三方支付/商店
- 内容调查未填完，或 AI 披露与实际包体不符
- 缺某币种价格导致该地区不可购买
- 用 Steam 钱包余额缴 $100（不支持）

## 中国主体 / 与 TapTap 的关系

- Steam 全球发行**不需要中国版号、软著、ICP、防沉迷**；若要在大陆通过「蒸汽平台」运营，属另一套体系、需要版号
- 仍须遵守各上架地区法律与内容规范
- 与本项目其他渠道的区别：

| | Steam 全球 | TapTap 国际站 | TapTap 国区 PC |
|---|---|---|---|
| 版号/软著/ICP | 不需要 | 不需要 | 需要 |
| 前置费用 | $100/款 | 无 | 无 |
| 平台抽成 | 30% | 零分成 | 零分成 |
| 强制等待 | 21–30 天 + Coming Soon 2 周 | 无 | 有资质审核周期 |
| 包体 | Windows/macOS/Linux（SteamPipe） | 仅 Android APK | .zip/.7z 纯净包 |

## 官方参考

- Steam Direct：`https://partner.steamgames.com/steamdirect`
- 入门：`https://partner.steamgames.com/doc/gettingstarted`
- 快速入门（中文）：`https://partner.steamgames.com/doc/quickstart?l=schinese`
- 发行流程：`https://partner.steamgames.com/doc/store/releasing`
- 审核流程：`https://partner.steamgames.com/doc/store/review_process`
- 素材规格：`https://partner.steamgames.com/doc/store/assets`
- 宣传片：`https://partner.steamgames.com/doc/store/trailer`
- 构建上传：`https://partner.steamgames.com/doc/sdk/uploading`
- 定价：`https://partner.steamgames.com/doc/store/pricing`
- 发布日期：`https://partner.steamgames.com/doc/store/release_dates`
- Coming Soon：`https://partner.steamgames.com/doc/store/coming_soon`
- App Fee：`https://partner.steamgames.com/doc/gettingstarted/appfee`
