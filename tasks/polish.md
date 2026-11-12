# 《采邑春秋》体验打磨

目标是把 Windows 版打磨到《星露谷物语》那样耐玩、好读、有生活气息。以《采邑春秋》的井田、门客、六艺和初税亩为特色。已有两条可通关路线，它们是继续制作和回归的基础。

自动验证使用无窗口模式，运行命令默认传入 `--headless`。后续画面验证须采用不会在桌面显示游戏窗口的方案。

| 玩家体验 | 完成时要看到的证据 | 当前情况 |
| --- | --- | --- |
| 耕作清楚、有手感 | 从标题开新档，不查说明书就能找到公田、换种、判断水分和收获；窗口和镜头变化后仍能准确点田。 | 新档交接简说明公私田的收成去向。首次纳贡后标出第一茬私田，玩家可另行指路去谈轮作。拖动耕作有逐格反馈。种子栏可直达井田舆图，按成熟、待浇或断水逐格指路。「今夜安排」预览公私田新熟格数和缺水。还需初次玩家独立试玩。 |
| 封地有人生活 | 玩家知道去哪找熟人；重复来访会遇到熟悉的角色和新的对话，交谈、帮忙及重要决定会留下可见变化。 | 七位邻居有独立服饰，手记可标出人物和晚间去处。蒲宁在竹径等手记时，其他来客按原日程赴约。五位常规来客按时辰和天气去南路亭。晴夜，收工的具名门客会到亭东席案歇脚，有各自的晚间对白。蔡娘在西市陈列样绸，陶辛晴天沿西路去绸摊再回南路亭，指引随他跨关道。首次纳贡可接续渠伯轮作，季青的路粮可接续亭西歇脚处，谷雨合奏留下曲簿记录。还需完整人工试玩核对相遇节奏和对白重复感。 |
| 地图有可记住的地方 | 封地和野外有不同的地标、捷径和探索回报；地形有前后层次，路径、资源和敌人始终可辨。 | 封地北侧的石垒标出行走边界，两条关道延伸出镜头，草地与田埂在路肩交接。封地与竹涧随四季更换树形和地表，新井田从立桩到完工能在地图看出变化。南路亭、野果坳与浅滩有随天气和季节出现的小动物。竹涧舆图可沿木桥或浅滩指路到采集点、钓点、今日水迹和返程西门。西市舆图标出石板街和五处去处，买粮、交鱼和交时令单的指引过关后继续。三处水迹可跨日记录，回封地可开药圃。还需初次玩家验证路线指引。 |
| 多天经营仍有选择 | 开局之外，公私田、工艺、门客与探索互相带来取舍；试玩记录能指出多种有效策略以及会令人反复刷同一动作的段落。 | 夜间备粮减少双结局回放里的手动转粮与购粮，收割岗可用每夜额外一份口粮换取田间帮手。缺粮时可选优先分餐的门客，睡前看谁会缺餐或离任。照料门客可逐格或按井田安排私田续播。记完轮作簿后可让门客交替播种菽和另一种作物，田格显示下茬和缺水。去西市或竹涧时门客继续田务，回封地可查收成去向。鱼摊每季有一张留鱼单，可在铜钱、口粮和另一张时令单之间取舍。初税亩可比较本局成熟作物、门客粮耗、两条结局与延期经费。仍需人工长线试玩核对节奏。 |
| 声音、美术和故事统一 | 人物、农事和地点有可辨的声音与动作，重要节点能看见人物和封地的变化；设置可调音量和画面。 | 谷雨的雨声在封地、竹涧和西市间连续播放，入室渐轻，西市虫鸣随季节变化。竹涧有溪水、晴天林鸟、近岸蛙鸣和与地表对应的脚步声。渠伯成功浇水时能在田边听见倒水声。谷雨亭集、战斗预警和四种农事有独立音效。双结局各有封地内的镜头、使者行走和筝声短曲，结算按本局经历显示邻里记事。后续仍需补齐其他关键情节的声音。 |
| 成品可交付 | Windows 成品解压后能跑完两条路线并恢复存档；两种窗口尺寸下实际操作；根据首次试玩与长线试玩记录修正阻塞和疲劳点。 | 最新 Windows 包通过手动和委派备粮的双结局、战败恢复、初税亩研究及 0.1.x 旧档迁移。结局可保存、重看和跳过，旧通关档直接恢复结算。过夜后退出重启、选档回退和坏档恢复已有专项证据。最终打磨版尚未验收。 |

## 从新档到第一次收获

- 封地手记分开显示目标和下一步；日历、物资和状态条缩到角落。开场人物站在田边，露出中央公田。
- 同一田格会预告翻地、播种、浇水、等候或收获。选种按钮与 1–7 同步；缺水、体力不足的点击不改变田地。湿土和产出数量给出结果。
- Godot 4.7.2 导入、脚本加载、主场景启动和 15 个回归场景通过，包含公私田、水利、节气与轮作、访客、战斗、存读档及两条结局。Vulkan 实机从标题开始，在 1280×720 与 1024×768 窗口验证了换种、缺水、浇水、过夜、公私田收获和打开管理。
- [开局改动前](../build/polish-opening/before/new-estate.png) · [首次纳贡](../build/polish-opening/after-1280x720/05-first-tribute.png) · [窄窗口缺水提示](../build/polish-opening/after-1024x768/02-dry-rice.png)

## 南路亭与封地人物

- 手记显示当天来客的去处。按 E 可与当前选中的来客或门客交谈。门客完成手上的活后回到岗位，分派教习、缫丝和守卫会改变他们活动的地方。
- 认识季青并首次纳贡后，再见时可送一份私田作物作路粮。南路亭会出现粮匣，季青的对白和表情会变化。第一位门客渠伯也有专用头像，会提起首次纳贡。
- 同日存读档恢复来客、交谈和招募状态，旧档保留相识记录。用正常新档验证了送粮、招募、分派教习和重读。Godot 4.7.2 的 15 项回归通过，传统和改革均走到结局。在 1280×720 和 1024×768 窗口完成了同一段实机互动。
- [季青托付路粮](../build/polish-neighbors/1280x720/03-request.png) · [送粮后重访](../build/polish-neighbors/1280x720/04b-provisions-thanks.png) · [窄窗口的教习对话](../build/polish-neighbors/1024x768/05-teaching.png)

## 东关与竹涧

- 由封地东关进入竹涧，回程落在东关内。木桥和浅滩连成回路，深溪会挡住行走。野果坳能补粮，东岸的望溪台有野药。两者每天可取其一，气血满时采药不消耗机会。
- 树冠与角色按脚下位置绘制。谷雨可见雨线，溪面有流动，四季用不同的林地、道路和水色。1280×720 与 1024×768 的 Vulkan 回放走过了树荫、两处过溪点和望溪台，也复核了扩建后两块井田旁的东关道路。
- 源码通过 16 项回归，覆盖两条结局、两岸通行、日推进和采集记录。独立 Windows 包解压验证了启动、两条结局、战败、初税亩研究，以及用 0.1.0 和 0.1.1 生成的存档。
- [竹涧 Windows 试玩包](../build/polish-trail/Fiefdom-trail-preview-Windows-x64.zip) · [扩建后的东关道路](../build/polish-trail/1280x720/01-expanded-estate-road.png) · [谷雨](../build/polish-trail/1280x720/06-guyu-rain.png) · [立秋](../build/polish-trail/1280x720/08-autumn.png)

## 竹涧地图与声音素材

- 从 ACTG 的 CC0 图集中选取垂柳和岸草，按河岸位置布置并随季节和天气调色。两处过溪点都经过走路验证。
- 使用 CC0 溪流录音、雨声和脚步。走近溪流时声音渐强，木桥和浅滩会切换脚步，谷雨时封地和竹涧都有雨声。设置可单独调节环境和脚步音量，旧设置读取默认环境音量。
- Godot 4.7.2 的 16 项回归通过。1280×720 与 1024×768 的 Vulkan 回放验证了干天过桥、涉水和谷雨。录制的环境声在西门处无声，在木桥前有溪声。Windows 独立包通过两条结局、战败恢复、初税亩研究及两个旧版本存档。
- [Windows 试玩包](../build/polish-materials/Fiefdom-materials-preview-Windows-x64.zip) · [木桥实机画面](../build/polish-materials/1280x720/02-willow-at-the-bridge.png) · [游戏内录音](../build/polish-materials/bamboo-ravine-audio.mp3) · [素材出处](../docs/Windows试玩说明.txt)

## 市场与研读

- 市场在成交前显示数量和收支。三夜口粮按当前门客的耗粮补缺，先转作物，再用铜钱购粮。资源不足时，整笔备粮都不会扣款或扣库存。
- 简册每天可研读一次，默认增加 50 点书经验。过夜后可再读，同一天存读档会保留已研读记录。六艺页在达标时指出蚕室和水利的入口。
- 同量转粮的通关回放中，传统路线从 120 次转粮降到 39 次，改革路线从 156 次降到 41 次。两条路线都在第 5 天达到书 3 级，并分别在第 59、61 天到达结局。
- Godot 4.7.2 的 17 项回归通过。1280×720 与 1024×768 窗口用鼠标和键盘实测了交易、备粮和研读。Windows 独立包通过两条结局、战败恢复、初税亩研究及 0.1.0、0.1.1 旧档读取。
- [经营试玩包](../build/polish-rhythm/Fiefdom-rhythm-preview-Windows-x64.zip) · [缺粮场景的市场预览](../build/polish-rhythm/1280x720/01-market-reserve.png) · [第五天研读](../build/polish-rhythm/1280x720/03-study-day-5.png) · [回放日志](../build/polish-rhythm/windows-release-check.log)

## 西廊样绸与夜间缫丝

- 认识陶辛后可织一匹样绸交付。默认按 45 铜钱结算为一次售绸。西廊出现样布，陶辛在交绸当天和留任后的对白不同，交付日期与售绸记录都进入存档。
- 墨家门客负责缫丝后可开启夜间委派。每名吃过晚饭的缫丝门客每晚处理一只茧。第二天的蚕桑页显示实际产出，欠粮时不会消耗蚕茧。
- 同一开局从新档回放至第 49 天。田地安排主要种麻并留一匹绸，蚕桑安排种三处桑、让渠伯缫丝并卖出织成的绸。

| 前两年回放 | 第一匹绸 | 第二块井田完工 | 口粮需求 | 手动缫丝 | 售绸 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 田地为主 | 第 14 天 | 第 23 天 | 175 份 | 2 次 | 0 匹 |
| 蚕桑与手动缫丝 | 第 8 天 | 第 22 天 | 219 份 | 24 次 | 18 匹 |
| 蚕桑与夜间委派 | 第 9 天 | 第 22 天 | 219 份 | 0 次 | 21 匹 |

- 田地回放有一夜欠粮，三组都击退 5 次来敌。详细记录见[田地回放](../build/polish-living-estate/comparison-estate.log)、[蚕桑手动回放](../build/polish-living-estate/comparison-workshop.log)和[蚕桑委派回放](../build/polish-living-estate/comparison-nightshift.log)。
- Godot 4.7.2 的 18 项回归通过。1280×720 与 1024×768 窗口按正常帧率走完交绸并返回标题，敌袭提醒留在管理界面上方。独立 Windows 包验证了两条结局、战败恢复、初税亩研究和两个旧版本存档。
- [Windows 试玩包](../build/polish-living-estate/Fiefdom-living-estate-preview-Windows-x64.zip) · [夜间缫丝](../build/polish-living-estate/1024x768/02-overnight-workshop.png) · [陶辛收样](../build/polish-living-estate/1280x720/04-sample-delivered.png) · [西廊样布](../build/polish-living-estate/1280x720/05-west-court-sample.png)

## 溪行手记与竹径药圃

- 和蒲宁交谈后，每天可到一处立牌记水迹。雨天优先木桥，晴天从当天对应的地标开始，跳过已记之处。采集与记事分开，回封地后可重读带日期和节气的三页。
- 三页记齐后蒲宁会在竹径等候，留任后则可以在他的岗位交还。交还后，竹径东侧出现有小路可达的药圃。取药后等三夜再长，满气血时可留着草药。
- 从新档第 5 天出发，第 6 天在谷雨记桥柱，第 7 天交还，第 10 天再采。读档恢复已记日期、每日限制和药圃再生。专门回放了先招募蒲宁的交接路径。
- Godot 4.7.2 的 19 项回归通过。1280×720 和 1024×768 的有窗口回放开启野外敌人，完成三趟出行、交接、取药和再生。Windows 包验证了两条结局、战败恢复、初税亩研究和 0.1.0、0.1.1 旧档。
- [Windows 试玩包](../build/polish-ravine-journal/Fiefdom-ravine-journal-preview-Windows-x64.zip) · [谷雨记水](../build/polish-ravine-journal/1280x720/03-rain-at-the-bridge.png) · [三页手记](../build/polish-ravine-journal/1280x720/05-three-journal-pages.png) · [竹径药圃](../build/polish-ravine-journal/1280x720/08-bamboo-herb-garden.png)

## 稻麦与竹丛素材

- 从 josehzz 的 Farming crops 16x16 选取稻和麦的三个阶段。田格用青金色区分成熟稻穗，用赭金色画麦穗，选种图标使用同样的颜色。
- 从 MightyKartz 的 Mountain Post 选取高竹。封地堂前、竹径和竹涧两岸的新竹丛随季节、天气调色，人物走到竹后时会淡出。两套素材的 CC0 1.0 出处随 Windows 包附上。
- 1280×720 与 1024×768 的 Vulkan 回放从标题进入封地，在通水的田格种稻，隔夜后存档并从标题继续，验证稻麦生长、收获、竹丛淡出和两处过溪。Godot 4.7.2 的 19 项回归通过。独立 Windows 包复核了两条结局、战败恢复、初税亩研究和 0.1.0、0.1.1 旧档。
- [Windows 试玩包](../build/polish-foraged-art/Fiefdom-crops-and-bamboo-preview-Windows-x64.zip) · [稻麦成熟](../build/polish-foraged-art/1280x720/03-ripe-rice-and-wheat.png) · [竹涧木桥](../build/polish-foraged-art/1280x720/05-bamboo-at-the-bridge.png) · [素材出处](../docs/Windows试玩说明.txt)

## 竹涧遇敌与东岗守备

- 野狗低吼后咬向扇形，斥候松弦前锁定箭路。侧走避开标记，留在范围内会吃到伤害。箭离弦有位置音效，命中显示伤害。
- 来敌毁田前标红一格。回放中收走一格成熟黍，来敌随后毁掉另一格。带着这场敌袭读档，玩家亲自射退来敌，留下一格作物。另一条回放按正常招募流程安排弋戎守卫，由他的箭守住作物。
- 可向来访或留任的弋戎复盘。他会说出谁放了末一箭、损了多少作物。东岗立牌后，靠近按 E 可读最新战果。来敌前一天标出种类，来袭时升起警旗。
- Godot 4.7.2 的 20 项回归通过。1280×720 和 1024×768 的 Vulkan 回放检查了预警、命中、两段录音的触发及复盘。作物损失和次日预警的演示档缩短了敌袭日程。独立 Windows 包用默认伤害重现战败并恢复存档，传统与改革路线分别在第 56、59 天通关，也通过了研究与 0.1.x 旧档读取。
- [Windows 试玩包](../build/polish-defense/Fiefdom-east-watch-preview-Windows-x64.zip) · [野狗起手](../build/polish-defense/1280x720/02-dog-bite-cue.png) · [受袭田格](../build/polish-defense/1280x720/04-crop-under-threat.png) · [东岗守备牌](../build/polish-defense/1024x768/07-east-watch-log.png)

## 四季农事与拖动耕作

- 春桑、夏稻、秋稷、冬麦当季播种少一次供水过夜。夏末种下的稻在入秋和读档后都保留三夜成熟的进度。旧档中的既有作物按基础成熟周期恢复。
- 日历显示明日节气和天气。田格用水滴、菱形和叉号提示待浇、可收和断水，选种栏下方显示今夜能成熟的格数。悬停显示作物进度和轮作增收。
- 按住左键拖过同一块井田，按起手的动作逐格处理。首年同一安排逐格按下左键 360 次，按行拖动 173 次。两次都完成 360 次田间操作，得到 14 份纳贡、78 份私田收成、83 铜钱，开出 2 块井田并击退 3 次敌袭。
- Godot 4.7.2 的 21 项回归通过。1280×720 和 1024×768 的 Vulkan 回放验证了拖动、合计、天气、当令换种及稻田断水。Windows 包走完第 56 天的传统结局和第 59 天的改革结局，验证战败恢复和 0.1.0、0.1.1 存档迁移。
- [Windows 试玩包](../build/polish-farm-year/Fiefdom-field-calendar-preview-Windows-x64.zip) · [逐格首年回放](../build/polish-farm-year/year-click.log) · [拖动首年回放](../build/polish-farm-year/year-sweep.log) · [拖收三格](../build/polish-farm-year/1280x720/04-swept-harvest.png) · [秋季断水提示](../build/polish-farm-year/1024x768/07-autumn-rice-disconnected.png)

## 石墨勘渠与第二块井田

- 挖渠前可看到会接水的田格和费用。按住 Shift 预览填渠，标出会断水的田格和将停长的稻。悬停一段断渠可找到能补接的单格缺口。
- 相识的石墨会回应第一次实际靠渠水过夜的作物。勘渠后水源旁出现量水尺，施工可放样一整段，按 R 切换拐弯方向。确认时按新增渠格扣钱，钱不够或碰到井田时整段不施工。
- 新档回放在第 6 天与石墨勘渠，再用已满足开垦条件的资源验证扩建。第二块井田选址预览 3/9 格有水，完工后与预览相符。填掉公用渠口会影响两块井田的 7 格，一格稻停长。读档后补接，次夜继续生长。
- [石墨勘渠](../build/polish-estate-assets/1280x720/03-shi-mo-water-review.png) · [放样预算](../build/polish-estate-assets/1280x720/04-survey-preview.png) · [两田断水预览](../build/polish-estate-assets/1024x768/06-two-fields-cutoff.png)

## 堂前、南路亭与田间录音

- 从 Kenney 的 Roguelike/RPG pack 和 zwonky 的 Various Containers 取用两种谷袋和两种陶罐。按封地的土色调色，在堂前和南路亭布置了七处。道具按脚底位置排序，和井田或水渠冲突时隐藏。
- 翻土、播种、浇水和收获各接入一段 CC0 录音。四段均从游戏的音效通道录到，拖收三格也录到了收获声。音效、图块的来源和裁切说明随 Windows 包附上。
- Godot 4.7.2 的 22 项回归通过。1280×720 与 1024×768 的 Vulkan 回放核对了道具、农事音效和开垦预览。解压后的 Windows 包通过传统与改革两条结局、战败恢复、初税亩研究和 0.1.0、0.1.1 旧档。
- [Windows 试玩包](../build/polish-estate-assets/Fiefdom-estate-assets-preview-Windows-x64.zip) · [堂前实机画面](../build/polish-estate-assets/1280x720/01-hall-storage.png) · [南路亭实机画面](../build/polish-estate-assets/1024x768/07-south-pavilion-storage.png) · [游戏内农事录音](../build/polish-estate-assets/farm-foley-preview.mp3) · [素材出处](../docs/Windows试玩说明.txt)

## 田间动作与门客浇水

- 主角用木锄、种袋、水桶和镰刀做出不同动作，翻土、撒种、浇水和收获的痕迹出现在相应田格。快速拖过一行会给成功处理的每格各留一次反馈。弓箭也有独立的举弓姿势。
- 从新档播一格黍，观察渠伯提桶走过去并浇湿土壤。第二格在他倾桶前由玩家先浇，只出现一次水花。保存重进仍可见湿土。石墨勘渠前后使用同一人物的两张肖像，勘渠后拿着量水尺。
- 实机回放发现醒来时的节气字样盖住收获合计。现在节气与日期出现在过夜画面，三格收获的国库、私田作物和铜钱可以同时读清。
- Godot 4.7.2 导入、脚本加载、启动和 23 项回归通过。1280×720 和 1024×768 的 Vulkan 回放各验证了四种农事、渠伯浇水、晨间节气和石墨换像。解压后的 Windows 包通过传统与改革两条结局、战败恢复、初税亩研究和 0.1.0、0.1.1 旧档迁移。
- [Windows 试玩包](../build/polish-field-motion/Fiefdom-field-motion-preview-Windows-x64.zip) · [田间动作短片](../build/polish-field-motion/field-work.mp4) · [晨间节气](../build/polish-field-motion/final/1280x720/09-dawn.png) · [石墨的量水尺](../build/polish-field-motion/final/1280x720/08-shi-mo-with-gauge.png)

## 作物分仓与南路亭四季交货

- 私田收成按品种进仓。市场可指定品种，并预览将用的库存。批量卖作物或转粮优先使用混存作物和交货用量之外的余量。早期旧档的库存按原总量作为混存作物恢复。
- 南路亭旁按 E 或从管理打开时令单。春单要菽和黍，夏单要通水田种出的稻，秋单要稷和菽，冬单要麦和麻。交货前可读下季预告。交齐后选领铜钱或口粮，封地的交货簿换上结讫标记，已交数量和领奖选择随存档恢复。
- 专项回放从正常新档耕作、研读解锁水利、挖渠和交货，延后了敌袭以核对经济。第 4、10、15、21 天分别交完四单，第 25 天春单重新开放。两套安排都是 16 份私田收成、11 份纳贡。春秋领粮、夏冬领钱的回放剩 151 铜钱，春秋领钱、夏冬领粮的回放剩 136 铜钱、2 份口粮和 1 份麻。
- Godot 4.7.2 导入、脚本加载、启动和 24 项回归通过。1280×720 和 1024×768 的 Vulkan 回放从新档查看交货簿、分仓交易、交春单和重读收据。Windows 包验证双结局、战败恢复、初税亩研究和两份 0.1.x 旧档。
- [四季回放](../build/polish-season-orders/godot-smoke.log) · [春秋领粮回放](../build/polish-season-orders/FoodAtSpring.log) · [夏冬领粮回放](../build/polish-season-orders/CashAtSpring.log)
- [Windows 试玩包](../build/polish-season-orders/Fiefdom-season-orders-preview-Windows-x64.zip) · [市场扣货预览](../build/polish-season-orders/final/1280x720/03-bulk-sale-preserves-order-stock.png) · [春单备齐](../build/polish-season-orders/final/1280x720/05-spring-ready.png) · [窄窗口重读收据](../build/polish-season-orders/final/1024x768/07-receipt-after-reload.png)

## 竹涧、南路亭素材与谷雨亭集

- 从 MOMONGA 的图集裁出溪石、嫩芽和岸草，从 Mini Meadow 选取白花和粉花。两处都按当前地图的光照和季节调色。野果坳的林鸟录音随距离渐入，雨天让出声场给雨声。手铃录音用于迎客曲和编钟练习的敲击。四组素材均为 CC0 1.0，出处随 Windows 包附上。
- 清明日历预告亭集。谷雨到南路亭东找商音，四拍中至少命中三拍可记入曲簿并获得乐经验。试奏失败后可以重来，散集后和读档后仍可查看已有记录。专项回放覆盖同日轮访、不同年份的来客替换、鼠标和键盘输入，以及长帧跳过敲击区的回归。
- Godot 4.7.2 的 25 项回归通过。1280×720 和 1024×768 的 Vulkan 回放均完成 4/4 合奏并在散集后读簿，实际音轨录到了敲钟和晴天鸟鸣。解压的 Windows 包通过传统与改革结局、战败恢复、初税亩研究和 0.1.0、0.1.1 旧档迁移。
- [Windows 试玩包](../build/polish-sourced-assets/Fiefdom-sourced-assets-preview-Windows-x64.zip) · [谷雨亭集](../build/polish-sourced-assets/validated/1280x720/02-grain-rain-gathering.png) · [竹涧溪岸](../build/polish-sourced-assets/validated/1280x720/07-bamboo-ravine-bank.png) · [散集后读簿](../build/polish-sourced-assets/validated/1024x768/05-scorebook.png) · [素材署名](../docs/Windows试玩说明.txt)

## 邻里手记与亭西歇脚处

- 从封地手记打开邻里手记。角色初见后入册，可查今日去处、初见日期、已有故事和接下来的线索。老档的相识和完成事项会显示为旧日记录。
- 季青收到路粮后，改日再见会提出合修歇脚处。他在访客位置或留任岗位都能接续此事。出 12 铜钱后亭西出现木料，过夜接上小路并摆好长凳和水瓮。体力不足时按 E，每日可恢复最多 18 点。当天已歇过的状态随存档恢复。
- 专项从正常新档种田并见到七人。第 2 天相识，第 7 天送粮并招募，第 8 天在堂前出资，第 9 天歇脚。回放延后敌袭，覆盖钱不够、体力已满、备料中读档、重复休息和旧档来客接续。1280×720 与 1024×768 的 Vulkan 回放从这份第 8 天存档继续，实测了按钮、对话、过夜和长凳。
- Godot 4.7.2 导入、脚本加载、启动和 26 项回归通过。解压后的 Windows 包使用默认敌袭验证了两条结局、战败恢复、初税亩研究和 0.1.0、0.1.1 旧档读取。
- [Windows 试玩包](../build/polish-neighbors-rest/Fiefdom-neighbor-journal-preview-Windows-x64.zip) · [邻里手记](../build/polish-neighbors-rest/final/1280x720/07-remembered-together.png) · [亭西长凳](../build/polish-neighbors-rest/final/1280x720/05-bench-at-dawn.png) · [窄窗口歇脚](../build/polish-neighbors-rest/final/1024x768/06-rest-at-the-bench.png)

## 竹涧垂钓与溪鱼簿

- 与蒲宁交谈后可去柳湾或砾滩。抛竿扣 5 点体力，等浮标下沉再提竿，交替按住和松开使张力留在绿段。鱼获和采果、采药共用当天的一次外出机会，收竿或失手后可再试。
- 溪鱼簿显示鱼篓、今天两处钓点的鱼情、首获日期和地点。带鱼回市集可逐尾留作口粮或卖铜钱，鱼处理后首获记录仍随存档保留。四种鱼按地图像素比例绘制，浮标水花采用 Allan Legemaate 的 CC0 录音。
- 新档专项在第 5 天向蒲宁学钓，清明在柳湾钓到鲫鱼，谷雨钓到鲤鱼，立夏钓到白鲦。切到第 13 天立秋后，从木桥过溪在砾滩钓到鳜鱼，并走浅滩回程。验证了取消、过早提竿、张力过高、同日次数、存读档和两种交易。专项暂停野外敌人的行动以核对两处路线。
- Godot 4.7.2 导入、脚本加载、启动和 27 项回归通过。1280×720 回放了柳湾鼠标收线和留粮，1024×768 回放了砾滩键盘收线和售鱼，两个窗口都从游戏音轨录到了水花声。解压的 Windows 包通过双结局、战败恢复、初税亩研究和 0.1.0、0.1.1 旧档读取。
- [Windows 试玩包](../build/polish-creek-fishing/Fiefdom-creek-fishing-preview-Windows-x64.zip) · [柳湾收线](../build/polish-creek-fishing/validated/1280x720/03-reeling.png) · [砾滩起鱼](../build/polish-creek-fishing/validated/1024x768/04-catch.png) · [溪鱼簿](../build/polish-creek-fishing/validated/1024x768/06-exchange-receipt.png)

## 封地与竹涧的四季

- 封地和竹涧新增四季阔叶树和花树，冬季换成枯枝、覆雪的松树和冬柳。春瓣、夏草、秋叶和冬霜沿林地分布，冬季溪心仍有流水。树木沿用脚下排序和遮挡淡化。
- 雪地播放从 Frigus_XIII 的 CC0 实录剪出的两段单步，并留下几秒后淡去的脚印。冬天走上木桥和踩进浅滩时，分别听到木板与踩水声。渠水和井田显示在积雪地表上方。 [雪地录音](https://freesound.org/people/Frigus_XIII/sounds/447126/)
- Godot 4.7.2 导入、脚本加载、启动和 28 项回归通过。专项跳到季末并正常过夜，验证四季切换、读档、雪上建渠和雪地走路。1280×720 与 1024×768 的 Vulkan 回放从东关进竹涧拍摄同机位四季，并从环境音通道录到踩雪声。专项和拍摄延后敌袭并暂停野外敌人；解压后的 Windows 包使用默认规则通过传统与改革结局、战败恢复、初税亩研究和 0.1.0、0.1.1 旧档迁移。
- [Windows 试玩包](../build/polish-four-seasons/Fiefdom-four-seasons-preview-Windows-x64.zip) · [立春](../build/polish-four-seasons/validated/1280x720/ravine-spring.png) · [立夏](../build/polish-four-seasons/validated/1280x720/ravine-summer.png) · [立秋](../build/polish-four-seasons/validated/1280x720/ravine-autumn.png) · [立冬](../build/polish-four-seasons/validated/1280x720/ravine-winter.png) · [雪地脚印](../build/polish-four-seasons/validated/1280x720/ravine-winter-prints.png) · [踩雪录音](../build/polish-four-seasons/validated/1280x720/snow-walk.wav)

## 渠伯的两茬收成

- 首次公田收成入国库后，可找渠伯约定在私田试轮作。收菽会在土里留肥。在同格收下下一茬非菽作物后，手记留下实际的作物、井田编号和日期。记簿后，渠伯的画像会换成抱簿的样子，井田西南也接出通往轮作簿的短路。翻簿可把还留肥的格子用金框标 12 秒。
- 渠伯离任后，每逢第 3、6、9 天等会回井田西南。当天的常规来客照常赴约，玩家可以继续同渠伯交谈或记簿。记簿后对话随季节和雨天变化。翻簿的短声取自 CC0 竹片实录。[原始录音](https://freesound.org/people/michorvath/sounds/386888/)
- 29 项回归通过。1280×720 和 1024×768 的 Vulkan 回放按天从新档种到第 8 天记簿，第 9 天再次找到离任的渠伯。回放通过游戏的键鼠入口耕作、过夜和交谈，延后了敌袭并用测试操作模拟离任。覆盖公私田结算、两次读档、旧档接续和标记肥地，两个窗口都从游戏音轨录到翻簿声。
- 解压后的 Windows 包完成渠伯专项。默认规则下另行验证传统与改革两条结局、战败恢复、初税亩研究和 0.1.0、0.1.1 旧档。
- [Windows 试玩包](../build/polish-field-keeper/Fiefdom-field-keeper-preview-Windows-x64.zip) · [田边约定](../build/polish-field-keeper/validated/1280x720/01-a-promise-in-the-field.png) · [邻里手记](../build/polish-field-keeper/validated/1280x720/03-neighbor-journal.png) · [轮作簿](../build/polish-field-keeper/validated/1024x768/04-rotation-book.png) · [标出肥地](../build/polish-field-keeper/validated/1280x720/05-fertile-plot.png) · [回访](../build/polish-field-keeper/validated/1280x720/06-returning-neighbor.png)

## 夜间备粮与用粮记录

- 「今夜口粮」可从睡觉按钮上方或市集打开。开启后，过夜只补当晚缺口，先用时令单之外的作物，再按每夜铜钱上限购粮。换季当晚按次日时令单留货。整笔凑不齐时保留作物和铜钱，门客照粮仓实际存粮用餐。面板显示预览与上次实际转用的品种、费用和用粮，设置与记录随存档保存。
- 解压后的同一 Windows 包分别从新档跑完手动和委派两组。委派组每夜购粮上限设为 25 铜钱，按需要手动补开垦用粮。结局日、结算进度和欠粮夜数一致。

| 路线 | 结局日 | 手动转粮 | 手动购粮 | 委派执行 | 欠粮夜数 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 传统 · 手动 | 56 | 37 | 32 | 0 | 4 |
| 传统 · 委派 | 56 | 4 | 6 | 40 | 4 |
| 改革 · 手动 | 59 | 40 | 31 | 0 | 1 |
| 改革 · 委派 | 59 | 4 | 4 | 46 | 1 |

- Godot 4.7.2 的 30 项回归通过。1280×720 与 1024×768 的 Vulkan 回放从旧档测试手动默认、键盘填上限、春夏换单、睡前预览和次日收支。测试档设置了指定作物和两名专职门客。Windows 包另行通过旧档迁移、战败恢复与初税亩研究。本机解压包连续运行 90 秒，完成 25 次管理界面开关和田间操作，推进到第 8 天。 [连续运行记录](../build/polish-night-rations/windows-verification/soak.log)
- [Windows 试玩包](../build/polish-night-rations/Fiefdom-night-rations-preview-Windows-x64.zip) · [睡前预览](../build/polish-night-rations/validated/1280x720/02-tonights-plan.png) · [过夜结算](../build/polish-night-rations/validated/1280x720/03-dawn-settlement.png) · [换季留货](../build/polish-night-rations/validated/1024x768/04-saved-receipt-and-next-order.png) · [回放记录](../build/polish-night-rations/windows-release-check.log)

## 七位邻居的地图造型与动作

- 按现有肖像绘制七套 32×32 地图小人，分别用帽形、衣色和随身物区分。接近交谈时人物会转身，走动时按实际位移交替迈步。石墨招募前后、门客列表与读档后沿用同一套造型。
- 渠伯提桶走到田边，成功浇水时在田边播放倒水声。田格提示尽量移到正在工作的门客下方。录音节选自 zembacraftworks 的 CC0 倒水实录。[原始录音](https://freesound.org/people/zembacraftworks/sounds/427392/)
- 31 项回归通过。两种 Vulkan 窗口均通过自动浇水、转身交谈、招募和读档回放。七人合照在回放中临时摆位。Windows 解压包完成邻居专项、两条结局、夜间备粮、战败恢复、初税亩研究和两份旧档接续。
- [Windows 试玩包](../build/polish-neighbor-motion/Fiefdom-neighbor-motion-preview-Windows-x64.zip) · [七人合照](../build/polish-neighbor-motion/validated/1280x720/06-seven-neighbors-study.png) · [提桶浇水回放](../build/polish-neighbor-motion/retainer-water.mp4) · [水源旁的石墨](../build/polish-neighbor-motion/validated/1024x768/04-shi-mo-at-the-water-source.png)

## 南路亭和竹涧的小动物

- 从 Ivan Voirol 的 Butterflies 取两款俯视像素蝴蝶，制成三帧振翅动画。春夏晴天分别在南路亭花丛和竹涧野果坳入口活动。 [蝴蝶素材](https://opengameart.org/content/butterflies)
- 从 scriptoy 的 Pixel Frog 取小蛙的蹲姿和跳姿，调色后放到浅滩西侧的溪石旁。走近会惊动小蛙，入水后浮现短暂水纹，离开一段距离才会回到岸上。春夏偶有蛙鸣，按距离与环境音设置播放。三项素材均按 CC0 1.0 使用，署名随 Windows 包附带。 [像素蛙素材](https://opengameart.org/content/pixel-frog-1616) · [蛙鸣录音](https://freesound.org/people/clif_creates/sounds/802737/)
- 32 项 Godot 回归通过。解压后的 Windows 包另行通过小动物专项、手动和委派经营的双结局、战败恢复、初税亩研究及 0.1.0 与 0.1.1 旧档接续。专项从标题新建、沿路进出竹涧并用正常睡觉触发谷雨与立冬，跳过了中间日期并暂停野外敌人的物理更新。
- 1280×720 和 1024×768 窗口都观察到振翅、起跳和水纹，游戏音轨录到近岸蛙鸣。窄窗口初次回放的退出阶段报告背景音占用资源，回放改为先卸载场景并停止背景音乐，两种窗口重跑后退出日志均无报错。
- [Windows 试玩包](../build/polish-creek-wildlife/Fiefdom-creek-wildlife-preview-Windows-x64.zip) · [南路亭蝴蝶](../build/polish-creek-wildlife/final/1280x720/01-pavilion-butterfly.png) · [小蛙起跳](../build/polish-creek-wildlife/final/1280x720/04-frog-leap.png) · [有声回放](../build/polish-creek-wildlife/creek-frog.mp4)

## 首次纳贡与邻里指路

- 从上一版解压包走到南路亭以南，公田在视野上方，手记仍只提示找金边公田。新版在公田露出时标出具体田格，牌子放在井田外。走远时箭头贴近屏幕边缘并避开界面。缺渠水时标出黍种，水已到田时标出睡觉。供水后保存，从标题继续会按田况恢复提示。
- 第一次公田收成直接入国库，手记开始显示后续纳贡进度。渠伯在场时可循标记找他谈轮作。邻里手记也可对在场人物点「在地图上找」。交谈、取消或人物离场后清除标记。
- 33 项 Godot 回归通过。1280×720 和 1024×768 窗口从标题新建、走远、用滚轮缩放、换种、耕作、保存和继续，经过两次正常睡觉在第 3 天纳贡并约好轮作。回放用游戏输入和正常菜单，返回标题时触发了确认对话的确认按钮。解压包的 Vulkan 回放同样通过，另行验证双结局、夜间备粮、战败恢复、初税亩研究和两份 0.1.x 旧档。独立首次试玩仍待验证。
- [Windows 试玩包](../build/polish-estate-directions/Fiefdom-estate-directions-preview-Windows-x64.zip) · [改动前走到南路亭](../build/polish-estate-directions/before/02-public-plot-beyond-view.png) · [解压版公田指路](../build/polish-estate-directions/windows-verification/opening-1280x720/02-find-the-plot-from-the-pavilion.png) · [窄窗口睡觉提示](../build/polish-estate-directions/release-visual/1024x768/04-sleep-after-watering.png) · [在地图上找](../build/polish-estate-directions/windows-verification/opening-1280x720/06-locate-a-neighbor.png)

## 晨间存档与恢复

- 上一版解压后从新档睡到第 2 天，公田生长一阶，回标题时仍没有可继续的存档。新版在作物、口粮和敌袭等过夜结算完成后自动保存。选定初税亩方案后也保存一次。经费不足触发的强制抉择能随晨间档重新打开。
- 最近三份自动档按保存顺序轮换，手动档仍由设置更新。标题显示最近存档的日期和来源，可直接继续或打开列表挑选。设置可关闭自动保存。写入失败会提示，已有档保持完整。坏档可回退到下一份可用档。战败及失地恢复使用本局已经到过的存档。
- 34 项 Godot 回归通过，1280×720 和 1024×768 的 Vulkan 回放覆盖轮换、选档、关闭自动保存、写入失败和坏档回退。专项用隔离目录制造写入失败和坏档，并将进度推进到初税亩经费缴纳日前验证强制抉择。两次独立启动同一解压版完成了过夜存档和继续，均得到第 2 天、作物生长一阶、粮食 9 份，读取前后存档 SHA-256 相同。
- 独立 Windows 包通过两条结局、两种备粮方式、初税亩研究和 0.1.0 与 0.1.1 旧档接续。用默认敌人在竹涧战败后，仅凭晨间档恢复到第 2 天和满气血。完整人工长线试玩仍待验收。
- 同一解压包连续运行 90.477 秒，共处理 5,425 帧和 32 次管理界面往返。耕作推进到第 8 天，逐晚验证最新自动档与当天相符，最后保留三份自动档。 [连续运行日志](../build/polish-dawn-checkpoints/windows-soak/soak.log)
- [Windows 试玩包](../build/polish-dawn-checkpoints/Fiefdom-dawn-checkpoints-preview-Windows-x64.zip) · [晨间保存回显](../build/polish-dawn-checkpoints/windows-verification/relaunch/01-morning-saved.png) · [存档列表](../build/polish-dawn-checkpoints/final/1280x720/03-save-history.png) · [坏档回退](../build/polish-dawn-checkpoints/final/1024x768/05-recovered-from-damaged-save.png) · [解压版重启记录](../build/polish-dawn-checkpoints/windows-verification/relaunch/relaunch-check.txt)

## 堂前交谷帛与南路亭交新税册

- 两条路线达成时在本局封地演出约七秒。传统线从第一块公田移向堂前，召简走到谷帛旁。改革线从最新开垦的井田移向南路亭，召简走到新税册摊旁。演出期间隐藏界面、地点字样和农事浮字，可用 Esc 或按钮跳过，结算页可重看。
- 结算列出实际达成的路线条件，并从本局已完成的轮作簿、药圃、歇脚处、东岗守备、合奏和样绸中选取最多三项记事。保存后继续直接打开同一结算。没有路线起始记录的早期通关档显示已有总量。新演出沿用现有存档字段。
- 从 nanliu_music、Squidocto 和 Wastefield 的 CC0 录音中节选筝声、金属碗声和落钱声，排列成两段短曲。使者的三方向行走帧、谷帛和税册摊为本项目绘制。声音来源、修改方式和署名随包附上。[筝声](https://freesound.org/people/nanliu_music/sounds/847157/) · [金属碗声](https://freesound.org/people/Squidocto/sounds/255762/) · [落钱声](https://freesound.org/people/Wastefield/sounds/692071/)
- Godot 4.7.2 的资源导入、脚本加载、主场景启动和 35 项回归通过。结局专项覆盖保存、继续、重看、跳过、两种不同的邻里记事和缺少路线起始记录的旧档。1280×720 与 1024×768 的 Vulkan 回放观察到使者走到目的地，两种窗口的退出日志均无资源泄漏警告。两段有声短片使用布置的结局测试档，录制实际游戏音轨，各采集 78 帧。
- 同一个解压后的 Windows 包另行按默认规则从新档经营到第 56 天传统结局和第 59 天改革结局，并核对演出镜头、路线数据、保存和继续。手动和委派备粮两组均通关，战败恢复、初税亩研究、0.1.0 与 0.1.1 旧档接续通过。发行回放中原有的农事音效数量断言已改为核对现有音效配置，完整发行验证通过。
- 恢复目标后的验证环境限制了原临时目录的文件替换。验证在项目内的隔离目录和便携引擎副本中完成。用户要求自动验证不在桌面显示游戏窗口，此后统一采用无窗口方式。完整人工长线试玩仍待验收。
- Windows 连续运行入口 `Test-WindowsRelease.ps1 -Soak` 已改为无窗口模式。同一解压包在 `--headless` 下持续运行 90.509 秒，处理 5,427 帧、32 次管理界面往返并推进到第 8 天，保留三份自动档，最新档为第 8 天。双结局、战败恢复和初税亩研究在同一次无窗口发行检查中通过。另行用无窗口结局专项核对两条路线按 Esc 跳过后的结算和暂停状态。[无窗口发行检查](../build/polish-estate-epilogues/windows-headless-check.log) · [连续运行日志](../build/polish-estate-epilogues/windows-headless/soak.log) · [Esc 回归](../build/polish-estate-epilogues/ending-keyboard-check.log)
- [Windows 试玩包](../build/polish-estate-epilogues/Fiefdom-estate-epilogues-preview-Windows-x64.zip) · [默认规则的堂前演出](../build/polish-estate-epilogues/windows-verification/1280x720/ending-traditional-ceremony.png) · [默认规则的南路亭演出](../build/polish-estate-epilogues/windows-verification/1280x720/ending-reformed-ceremony.png) · [窄窗口结算](../build/polish-estate-epilogues/validated/1024x768/reformed-ledger.png)
- [传统线有声回放](../build/polish-estate-epilogues/traditional.mp4) · [改革线有声回放](../build/polish-estate-epilogues/reformed.mp4) · [Godot 回归](../build/polish-estate-epilogues/godot-smoke.log) · [Windows 发行验证](../build/polish-estate-epilogues/windows-release-check.log) · [素材署名](../docs/Windows试玩说明.txt)

## 熟人的返访日期与四季对白

- 邻里手记为五位常规访客标出下一次轮访的日期和地点。招募后条目切到门客岗位，蒲宁等候手记交接时会说明其他轮访为何顺延。专项从标题新建，正常过夜，在第 3 天看到季青的第 7 天约期，并在当天于南路亭再次遇到他。蒲宁第 11 天接过手记后留到当天结束，第 12 天按预告遇到石墨。
- 改动前在第 4 天完成勘渠，保存并读取后，来客从石墨变成陶辛。新版按同一规则生成地图来客和手记日期。第 9 天完成勘渠、第 10 天完成守备复盘后，同日读档分别保留石墨与弋戎。[改动前记录](../build/polish-neighbor-returns/before/visit-reload.log)
- 季青、石墨、陶辛、蒲宁和弋戎完成各自委托后，每季各有两段对白，雨天另有一段，共 45 段。石墨提到实际通水的井田数，蒲宁会说药圃还要几夜生长。断水和敌袭时先谈眼前的事。对白通过游戏中角色的交谈入口核对，45 段都在现有文本框内，旧日相识可读到下一次轮访。
- 专项补足了口粮和声望、延后常规敌袭，布置了委托进度和后期日期来覆盖四季。全部验证使用无窗口方式。Godot 4.7.2 导入、脚本加载、启动和 36 项回归通过。同一个解压后的 Windows 包完成邻里专项、手动和委派备粮的两条通关路线、战败恢复、初税亩研究和两份 0.1.x 旧档接续。完整人工长线试玩仍待验收。
- [Windows 试玩包](../build/polish-neighbor-returns/Fiefdom-neighbor-returns-preview-Windows-x64.zip) · [Godot 回归](../build/polish-neighbor-returns/godot-smoke.log) · [Windows 邻里专项](../build/polish-neighbor-returns/windows-neighbors/neighbor-returns.log) · [Windows 发行验证](../build/polish-neighbor-returns/windows-release-check.log)

## 门客收割与田间分工

- 「管理」的门客列表新增「田间收割」。收割门客在封地走向成熟作物并挥镰，按「封地概览」指定的田格优先收割。多名门客分头处理田格，手动先收下同一格时只结算一次。收割岗每夜多耗一份粮，计入备粮计划和实付口粮。
- 在同一份两块井田、八格成熟作物的测试档，手动收割用八次田间点击和 24 点体力。委派收割用零次田间点击和零点玩家体力。两次都得到两份纳贡、七份私田收成、48 铜钱和四片桑叶，保留菽茬地力和桑树再生。专项以设置好的后期农场比较收割，随后正常过夜核对额外粮耗。
- 挥镰途中保存后，读档恢复岗位、优先田格和当时的作物。新版存档格式区分未分派和地图上实际存在的坐标 `(-1, -1)`。早期存档原有岗位与优先格正常恢复。回放将两名收割门客分派到同一格，玩家先收时实际纳贡一份。
- 改革后，门客在改为私田的中心格采叶，得到一份计税收成、12 铜钱和四片桑叶。测试预置了其余通关条件，最后一格在睡觉淡出时触发结局。修复前推进到第 52 天并消耗四份粮，修复后以收获时的第 51 天和粮仓数量进入结局。[修复前回放](../build/polish-retainer-harvest/before-sleep-fix.log)
- Godot 4.7.2 导入、脚本加载、启动和 37 项回归通过。同一解压版用无窗口方式通过收割专项、手动与委派备粮的双路线、战败恢复及初税亩研究，并继续了 0.1.0、0.1.1 和上一版 1.0 试玩包实际生成的旧档。完整人工长线试玩仍待验收。
- [Windows 试玩包](../build/polish-retainer-harvest/Fiefdom-retainer-harvest-preview-Windows-x64.zip) · [Windows 收割回放](../build/polish-retainer-harvest/windows-harvest/retainer-harvest.log) · [Godot 回归](../build/polish-retainer-harvest/godot-smoke.log) · [Windows 发行验证](../build/polish-retainer-harvest/windows-release-check.log)

## 竹涧舆图与过溪路线

- 竹涧内按 M 或点右上角按钮打开舆图。舆图标出当前位置、两岸道路、七个地点和可记录的今日水迹。选定地点后回到山路，地面标记随玩家位置更新，到达后清除。
- 自动回放从标题新建，经东关入涧，用鼠标选望溪台并沿木桥走到野药旁，随后从砾滩经浅滩和西门回到封地东关。回放暂停野外敌人的行动，并预先设置与蒲宁相识，以核对水迹立牌、路线取消、垂钓面板的暂停状态及两种尺寸下的控件布局。
- Godot 4.7.2 的导入、脚本加载、启动和 38 项回归通过。同一解压后的 Windows 包通过舆图专项、手动与委派备粮的双结局、战败恢复和初税亩研究，并接续三份旧版程序生成的存档。全部验证用无窗口方式，舆图画面和首次玩家体验仍待人工验收。
- [Windows 试玩包](../build/polish-ravine-map/Fiefdom-ravine-map-preview-Windows-x64.zip) · [Windows 舆图回放](../build/polish-ravine-map/windows-ravine/ravine-map.log) · [Godot 回归](../build/polish-ravine-map/godot-smoke.log) · [Windows 发行验证](../build/polish-ravine-map/windows-release-check.log)

## 睡前田务与晨间记录

- 改动前的 Windows 新档中，第一夜一格公田漏浇，一格私田正常长了一阶。睡前面板只有口粮，过夜画面只有日期和节气。[改动前回放](../build/polish-field-nights/before/field-night-baseline.log)
- 「今夜安排」合并田务预览与用粮。玩家可查已有的成熟田格、明早新熟的公私田和停长原因。「找待浇田」优先标出待浇公田，同类里选最近一格，供水后清除标记。新熟格数在过夜时出现，最近一夜的田务和用粮可在晨间读档后重读。
- 键鼠回放从新档种下三格黍，核对漏浇、田格指引、季青如期来访、私田先熟、公私田同夜成熟、晨间档继续及公私田各自结算。测试固定了渠伯，另用布置好的旧档验证谷雨供水、断渠稻田停长及改革后中心格计为私田。两种尺寸下核对面板布局。实画面与首次游玩仍待人工验收。
- Godot 4.7.2 的导入、脚本加载、启动和 39 项回归通过。同一解压后的 Windows 包通过田务专项、手动与委派备粮的双结局、战败恢复、初税亩研究和三份旧版程序生成的存档接续。验证均使用无窗口模式。
- [Windows 试玩包](../build/polish-field-nights/Fiefdom-field-nights-preview-Windows-x64.zip) · [Windows 田务回放](../build/polish-field-nights/windows-field-nights/field-nights.log) · [Godot 回归](../build/polish-field-nights/godot-smoke.log) · [Windows 发行验证](../build/polish-field-nights/windows-release-check.log)

## 新井田的四晚施工

- 确认选址后在地图上立竹桩，前三晚依次清草、整地和划畦。封地手记的「找工地」指向最近的工地，悬停显示井田编号和剩余夜数。第四晚提示完工，原工地成为有公私归属的九格井田。清草阶段沿用了现有 CC0 碎石。 [Ninja Adventure 素材授权](https://pixel-boy.itch.io/ninja-adventure-asset-pack)
- 专项用备齐物资的上士存档错开一晚开工两处井田，并固定门客行动。键鼠回放核对两处开垦各扣一次粮钱、读档恢复不同阶段、寻找离玩家最近的工地、完工提醒和旧工地指引清除。第 8 天在第一处新井田收下公私各一份，分别入国库和私仓。
- Godot 4.7.2 的导入、脚本加载、启动和 40 项回归通过。解压后的同一 Windows 包另行通过工地专项、双结局、战败恢复、初税亩研究和三份旧版生成的存档接续。
- 1280×720 和 1024×768 窗口各取得五张 Windows Forward+ Vulkan 实际帧，核对立桩、清草、读档后的整地、划畦及完工。启动检查确认回放进程位于独立 Win32 桌面，系统输入桌面为 Default。1024×768 窗口按现有 16:9 比例输出 1024×576 内容。完整人工试玩仍待验收。 [微软的 Windows 桌面说明](https://learn.microsoft.com/en-us/windows/win32/winstation/desktops)
- [Windows 试玩包](../build/polish-field-worksites/Fiefdom-field-worksites-preview-Windows-x64.zip) · [划畦画面](../build/polish-field-worksites/rendered/1280x720/04-nine-plots-marked.png) · [窄窗口完工画面](../build/polish-field-worksites/rendered/1024x768/05-finished-well-field.png) · [渲染校验](../build/polish-field-worksites/rendered/manifest.txt) · [Godot 回归](../build/polish-field-worksites/godot-smoke.log) · [Windows 发行验证](../build/polish-field-worksites/windows-release-check.log)

## 初税亩的议税对照

- 改动前的 Windows 包在单击「支持改革」后立即执行。新面板并排显示三案与本局账目。预选可切换或按 Esc 清除，「定案」才执行并保存。 [改动前实画面](../build/polish-tax-council/before/1280x720/before-council.png)
- 同一存档的三格成熟作物，改革后收获四份私仓作物、28 铜钱、四片桑叶。传统下收获两份纳贡、三份私仓作物和 24 铜钱。键鼠回放确认实际入账与预估相符，覆盖田格转属、农家增产、轮作地力和每份税后取整。改革预览点明季青离开及每夜粮耗由四份降到两份，定案读档后可核对。
- 回放使用两份预设的第三年前后存档，固定门客行动并延后敌袭。第 48 天睡下后，次日刚成熟的田格计入预估。选择暂缓后，到首笔经费日显示尚差 13 铜钱并呈现两案。全额缴费到期由发行研究回放另行验证。
- Godot 4.7.2 导入、脚本加载、启动和 41 项回归通过。解压后的同一 Windows 包通过议税专项、双结局、战败恢复、研究期限及三份旧版程序生成的存档接续。1280×720 与 1024×768 的 Vulkan 键鼠回放在隔离桌面完成。完整人工长线试玩仍待验收。
- [Windows 试玩包](../build/polish-tax-council/Fiefdom-tax-council-preview-Windows-x64.zip) · [三案对照](../build/polish-tax-council/rendered/1280x720/02-reform-selected.png) · [窄窗口最终抉择](../build/polish-tax-council/rendered/1024x768/03-final-research-choice.png) · [渲染校验](../build/polish-tax-council/rendered/manifest.txt) · [Godot 回归](../build/polish-tax-council/godot-smoke.log) · [Windows 发行验证](../build/polish-tax-council/windows-release-check.log)

## 封地舆图与在场人物

- 封地按 M 或点顶部「舆图」暂停并打开地图。按实际坐标绘出道路、位置、通水与未通水的沟渠、九格井田和工地。地点、井田和人物三页可点选指路。井田显示渠水覆盖和可收格数，工地显示施工阶段与剩余夜数。人物页显示在场来客和门客的头像、位置，并注明来访地点或当前岗位。
- 键鼠回放从新档打开舆图并核对渠伯的位置与农事拖拽结束。扩建场景使用预置的四块井田、通水与断渠。地图显示首块井田三格有渠水、一格可收，选中第二块工地后走到实际坐标。玩家沿标记找到季青并交谈。过两夜后，舆图显示已完工的井田和当日来客。回放从东关进入竹涧，随后经西门返回封地。
- 在 1280×720 和 1024×768 的 Windows Vulkan 回放中查看三页画面。首次取帧发现窄窗口的目标圈压住「南路亭」。地名现会避开目标和其他标记，并以细线指向所在位置。两次最终取帧的隔离桌面都不同于输入桌面。 [修订前人物页](../build/polish-estate-map/before-caption-layout/03-present-neighbors.png) · [修订后人物页](../build/polish-estate-map/rendered/1024x768/03-present-neighbors.png)
- Godot 4.7.2 导入、脚本加载、启动和 42 项回归通过。解压后的同一 Windows 包通过舆图专项、双结局、战败恢复、研究期限和三份旧版程序生成的存档接续。完整人工长线试玩仍待验收。
- [Windows 试玩包](../build/polish-estate-map/Fiefdom-estate-map-preview-Windows-x64.zip) · [井田舆图](../build/polish-estate-map/rendered/1280x720/02-field-survey.png) · [渲染校验](../build/polish-estate-map/rendered/manifest.txt) · [Windows 舆图回放](../build/polish-estate-map/windows-estate-map/estate-map.log) · [Godot 回归](../build/polish-estate-map/godot-smoke.log) · [Windows 发行验证](../build/polish-estate-map/windows-release-check.log)

## 从第一次纳贡到开垦第二块井田

- 旧 Windows 包的新档中，下士点开垦会看到水源和间距的通用提示，且面板按下士显示 70 铜钱、30 份粮。新面板将爵位、田额、门客和粮钱列在同一处，按实际能增加田额的爵位估算。默认第二块井田需要三名门客、140 铜钱和 60 份粮。手记说明招募的声望开支，晋升当日显示新爵位和田额。 [旧版回放](../build/polish-reclamation/before/reclamation-baseline.log)
- 面板可指向当日来客或打开市场。田额允许时可勘地，九格预览显示渠水和具体的选址问题。立桩前会写明扣费后的粮仓余量和门客每夜所需。按下「立桩定界」只支付一次，回执记录实付与库存，可直接指向工地。 [初次勘地](../build/polish-reclamation/rendered/1280x720/03-selected-site.png) · [立桩回执](../build/polish-reclamation/rendered/1024x768/04-staked.png)
- 默认难度的新档键鼠回放先耕公田和私田，与来客交谈并挡住首轮敌袭。第 12 天以 100 声望升任中士，招到季青和石墨，第 13 天立桩。备粮供三名门客吃过施工的四夜。第 17 天从晨间档继续，在新井田公田播种。回放由脚本选择耕作、拜访和备粮时机。完整人工试玩仍待验收。
- Godot 4.7.2 的导入、脚本加载、启动和 43 项回归通过。解压后的同一 Windows 包通过新档扩建、双结局、战败恢复、研究期限和三份旧档接续。1280×720 和 1024×768 两次隔离桌面 Vulkan 回放各保存五张实画面。
- [Windows 试玩包](../build/polish-reclamation/Fiefdom-reclamation-preview-Windows-x64.zip) · [新档扩建回放](../build/polish-reclamation/windows-reclamation/estate-progress.log) · [渲染校验](../build/polish-reclamation/rendered/manifest.txt) · [Godot 回归](../build/polish-reclamation/godot-smoke.log) · [Windows 发行验证](../build/polish-reclamation/windows-release-check.log)

## 来客的回访路线

- 一起修好的设施会改变五位常规来客的去处。季青去亭西看水瓮，石墨在水源看量水尺，陶辛到西廊理绸，蒲宁走到药圃，弋戎沿东路去守备牌。来客走到设施旁会面向它，按 E 可以在途中停下交谈，结束后继续走。封地手记、邻里手记和舆图读取实际位置，下一次回访的地点根据已建成的设施预告。
- 改动前的 Windows 版用已建好歇脚处的测试档复现季青仍在南路亭。新版以默认难度从新档耕作、交路粮、出钱修歇脚处，第 22 天走到亭西。回放在他途中打开舆图跟踪，验证交谈暂停步行、关窗后到达、歇脚处可单独交互，以及继续游戏时在当天的活动地点恢复。 [旧版位置](../build/polish-visitor-routes/before/visitor-route-baseline.log)
- 预置已记录水迹的存档中，蒲宁接过手记后实际沿新路走到药圃。其余三个活动点用已有故事进度的存档核对。取帧时发现守备消息会盖在舆图上，现随舆图开关隐藏和恢复。亭前路牌与行走人物提示仍可能短暂重叠。 [蒲宁到药圃](../build/polish-visitor-routes/rendered/1024x768/04-herb-garden-after-handoff.png) · [追踪季青](../build/polish-visitor-routes/rendered/1024x768/02-person-on-the-map.png)
- Godot 4.7.2 的导入、脚本加载、启动和 44 项回归通过。解压后的同一 Windows 包通过来客专项、双结局、战败恢复、研究期限和三份旧档接续。1280×720 与 1024×768 均在隔离桌面取帧。完整人工试玩仍待验收。
- [Windows 试玩包](../build/polish-visitor-routes/Fiefdom-visitor-routes-preview-Windows-x64.zip) · [季青到亭西](../build/polish-visitor-routes/rendered/1280x720/03-at-the-water-jar.png) · [Windows 回放](../build/polish-visitor-routes/windows-visitor-routes/visitor-routes.log) · [渲染校验](../build/polish-visitor-routes/rendered/manifest.txt) · [Godot 回归](../build/polish-visitor-routes/godot-smoke.log) · [Windows 发行验证](../build/polish-visitor-routes/windows-release-check.log)

## 标题、封地四季与竹涧配乐

- 为标题、封地四季和竹涧分别编排曲目。四季和竹涧的曲长约 3 分 44 秒至 4 分 47 秒。古琴、筝和笛子采用授权单音录音，剪辑、变调后编成新曲。采样的作者、授权和修改方式随 Windows 包提供。 [古琴录音与授权](https://freesound.org/people/RafaelCaro/sounds/176266/) · [古筝录音与授权](https://freesound.org/people/nanliu_music/sounds/847157/) · [笛子录音与授权](https://freesound.org/people/CarlosCarty/sounds/339357/)
- 换季和进出竹涧时两首曲子在约 1.45 秒内渐变。同季过夜继续播放，返程接回封地曲。标题和封地的设置都有独立音乐音量，旧设置默认 80%。编钟练习和结局演出会降低场景配乐，退出后恢复。
- 回放预置季末日期并延后敌袭，通过睡觉进入下一季，沿真实的东关和西门往返。1280×720 和 1024×768 的 Vulkan 回放在不可见的隔离桌面录下六首的实机音频和一声编钟，核对竹涧曲循环、返程续播及三条音量滑杆。窄窗口输出 1024×576 内容。整曲听感和新档到结局的长线人工试玩仍待验收。
- Godot 4.7.2 导入、脚本加载、启动和 45 项回归通过。解压后的同一 Windows 包通过配乐专项、双结局、战败恢复、研究期限和三份旧版存档接续。
- [Windows 试玩包](../build/polish-seasonal-score/Fiefdom-seasonal-score-preview-Windows-x64.zip) · [配乐节选](../build/polish-seasonal-score/Fiefdom-soundtrack-preview.mp3) · [窄窗口音量设置](../build/polish-seasonal-score/rendered/1024x768/music-settings.png) · [实机录音与截图校验](../build/polish-seasonal-score/rendered/manifest.txt) · [Godot 回归](../build/polish-seasonal-score/godot-smoke.log) · [Windows 发行验证](../build/polish-seasonal-score/windows-release-check.log)

## 昼夜、堂前过夜与井田路缘

- 封地与竹涧共用时辰，默认用两分半从卯时走到亥时。黄昏起堂前、南路亭和路口的灯陆续亮起。地名、田格操作和敌袭预警使用独立于夜色的显示材质。夏秋晴夜近处有虫鸣，鸟声随夜色渐弱。 [虫鸣录音与授权](https://freesound.org/people/Sclolex/sounds/210540/)
- 可从舆图找到堂前，靠近按 E 查看今夜田务和口粮，再点「过夜」。手动档保存当日时辰，选档时显示时辰。晨间自动档和早期无时辰字段的档从卯时进入当天。
- 同机位对照确认南侧旧路肩压入了首块井田。以原存档的九格坐标为基准，让主路绕到水源西边，横路在田南给田埂留出空间，再以小径接到下田口。石头移到草边，路缘用窄土边过渡。画面、舆图和脚步表面共用路形。 [修前井田](../build/polish-daylight/before-road-alignment/1280x720/01-estate-noon.png) · [修后井田](../build/polish-daylight/rendered/1280x720/01-estate-noon.png)
- 从新档按正常过夜走到第七天立夏。专项加快了日照变化，暂停了竹涧敌人的移动，通过真实东关和西门往返。在两种窗口尺寸的隔离 Vulkan 回放中分别录到虫鸣，核对过夜后公田生长一阶、粮仓消耗一份、晨间档时辰归零和酉时手动档恢复。长线人工试玩仍待验收。
- Godot 4.7.2 的导入、脚本加载、启动和 46 项回归通过。同一个 Windows 包通过双结局、战败恢复、初税亩研究及三份旧版程序生成的存档接续。
- [Windows 试玩包](../build/polish-daylight/Fiefdom-daylight-preview-Windows-x64.zip) · [堂前夜色](../build/polish-daylight/rendered/1280x720/04-hall-night.png) · [窄窗口过夜面板](../build/polish-daylight/rendered/1024x768/05-hall-plan.png) · [渲染与录音校验](../build/polish-daylight/rendered/manifest.txt) · [Godot 回归](../build/polish-daylight/godot-smoke.log) · [Windows 发行验证](../build/polish-daylight/windows-release-check.log)

## 井田位置、田埂与封地道路

- 首块井田往东移 16、往南移 24 个场景像素。土格、作物、水源和渠线跟随同一田格坐标，存档仍按原田格记录。重画南行道和东岗横路，路肩留在九格之外。南侧窄径接到田埂的开口，路边花草随路缘摆放。
- 专项核对九格的实际土格、点击位置和作物图层，确认路肩避开九格和接渠的草地。自动回放覆盖公私田、浇水、轮作、施工与旧档接续。在 1280×720 和 1024×768 两种窗口尺寸的不可见隔离桌面取帧，窄窗口输出 1024×576 的游戏画面。 [井田实画面](../build/polish-estate-layout/rendered/1280x720/estate-layout.png) · [窄窗口](../build/polish-estate-layout/rendered/1024x768/estate-layout.png)

## 东关与西门转场

- 东关和西门各自配置目的地与到达标记。相邻地图在进入场景后缓存，切图在淡出后执行。淡入时角色已站在对应路口并面向前进方向。保持方向输入可以接着走，缩放、时辰、浇水和选种会随往返保留。早期无选种字段的存档从黍种开始。
- 解压版通过两个方向的实际键鼠进出，四次实机转场用时 404 至 418 毫秒。无窗口专项模拟了到达标记缺失，核对返回原地图和重新进门，也验证了入关触发议税时的暂停状态。手动保存后继续恢复了选种与浇水。
- Godot 4.7.2 导入、脚本加载、启动和 47 项回归通过。同一解压包完成手动与委派备粮的两条通关路线、战败恢复、初税亩研究和三份旧版存档接续。完整人工长线试玩仍待验收。
- [Windows 试玩包](../build/polish-estate-layout/Fiefdom-estate-layout-preview-Windows-x64.zip) · [东关往返短片](../build/polish-estate-layout/road-transition-preview.mp4) · [渲染校验](../build/polish-estate-layout/rendered/manifest.txt) · [Godot 回归](../build/polish-estate-layout/godot-smoke.log) · [Windows 发行验证](../build/polish-estate-layout/windows-release-check.log)

## 来客的晚间去处

- 上一版在第 2 天从卯时走到戌时，季青仍站在白天的位置。新版的五位常规来客在晴天酉时沿路去南路亭，雨天申时提前到亭檐下。手记预告去处，舆图定位路上实际位置，到亭前可听各自的晴雨对白。 [改动前回放](../build/polish-pavilion-visits/before/visitor-after-dusk.log)
- 从新档耕作到第 2 天，回放与季青交谈、查看去处、在途中交谈并到灯下再见。开舆图时停表，返回后指路跟随。手动保存可恢复到亭前，早期无时辰存档从白天地点开始。回放从竹涧返回时恢复了弋戎所在的路段，也核对了途中读档。专项跳过部分游戏时辰，并用预置进度检查雨天与委托。
- 等勘渠、交溪行手记和守备复盘的来客在入夜后仍在约定地点，正常对话可继续交接。谷雨时另有三位亭集来客，曲簿标签移到书架下方以避开避雨的来客，靠近仍可单独翻阅。 [标签修订前](../build/polish-pavilion-visits/before-scorebook-layout/1280x720/05-rain-shelter.png) · [修订后窄窗口](../build/polish-pavilion-visits/rendered/1024x768/05-rain-shelter.png)
- Godot 4.7.2 资源导入、脚本加载、启动和 48 项回归通过。解压后的 Windows 包通过无窗口专项、两种备粮方式的双结局、战败恢复、初税亩研究和三份旧档接续。两个尺寸都在不可见的隔离桌面取得实画面。完整人工长线试玩仍待验收。
- [Windows 试玩包](../build/polish-pavilion-visits/Fiefdom-pavilion-visits-preview-Windows-x64.zip) · [邻里手记](../build/polish-pavilion-visits/rendered/1280x720/01-day-appointment.png) · [灯下对白](../build/polish-pavilion-visits/rendered/1280x720/04-evening-conversation.png) · [渲染校验](../build/polish-pavilion-visits/rendered/manifest.txt) · [Godot 回归](../build/polish-pavilion-visits/godot-final-smoke.log) · [Windows 发行验证](../build/polish-pavilion-visits/windows-release-check.log)

## 人物、建筑与道路的比例

- 实测站姿主角为 27 场景像素高，田格为 16×16。旧堂屋的门洞约 13 像素高，屋身和九格井田的宽度相近。新版以角色站高定门洞与檐下开口，以田格定道路宽度。斜俯视的屋顶、立面与脚底关系参考《星露谷物语》的官方实机画面。 [比例说明](../docs/game_design/11_美术音效需求.md#封地的同框比例) · [官方实机图库](https://www.nintendo.com/us/store/products/stardew-valley-nintendo-switch-2-edition-switch-2/)
- 按 96×72、80×64、72×60 和 64×64 的场景图框重绘堂屋、蚕棚、南路亭和关门。堂屋门洞约 24 像素高。进关主路、南行道与东岗横路的土面宽 32、22、18 像素，田口小径仍留出九格田与接渠的边界。交货簿的提示放到牌架下方。
- 回放用默认 2× 镜头从新档耕作、靠近堂前打开今夜安排，并沿真实路口往返。蚕棚用已建工坊的测试档取帧。旧版与新版以同一路线拍摄堂屋和南路亭，最终 Windows 包另在 1280×720 与 1024×768 两种窗口尺寸取得实画面，均在不可见的隔离桌面运行。 [同机位对照](../build/polish-world-scale/building-proportions.png) · [东关](../build/polish-world-scale/rendered/1280x720/05-east-gate.png)
- Godot 4.7.2 资源导入、脚本加载、启动和 49 项回归通过。解压后的同一个 Windows 包通过比例专项、两种备粮方式的双结局、战败恢复、初税亩研究和三份旧档接续。完整人工长线试玩仍待验收。
- [Windows 试玩包](../build/polish-world-scale/Fiefdom-world-scale-preview-Windows-x64.zip) · [渲染校验](../build/polish-world-scale/rendered/manifest.txt) · [Godot 回归](../build/polish-world-scale/godot-final-smoke.log) · [Windows 发行验证](../build/polish-world-scale/windows-release-check.log)

## 堂屋和井田的比例样板

- 堂屋由 96 × 72 扩到 128 × 88 场景像素。27 像素高的主角可以站在石前坪上，门面约 22 × 28。堂屋靠近南行道入口，首块井田的默认镜头可同时看清堂屋、人物和田格。南路亭新增接到亭口的步道。 [比例说明](../docs/game_design/11_美术音效需求.md#封地的同框比例) · [堂前同机位对照](../build/polish-estate-proportions/hall-proportions.png) · [井田边视野](../build/polish-estate-proportions/final-frames/1280x720/01-field-and-hall.png)
- Godot 4.7.2 导入、脚本加载、启动和 49 项回归通过。解压后的 Windows 包通过田边耕作、沿路走到堂前打开今夜安排、东关双向通行、双结局和三份旧档接续。两种窗口尺寸均在不可见的隔离桌面取帧。完整人工长线试玩待验收。 [Windows 试玩包](../build/polish-estate-proportions/Fiefdom-estate-proportions-preview-Windows-x64.zip) · [渲染校验](../build/polish-estate-proportions/final-frames/manifest.txt) · [Godot 回归](../build/polish-estate-proportions/godot-final-smoke.log) · [Windows 发行验证](../build/polish-estate-proportions/windows-release-check.log)

## 堂屋内的研读和歇息

- 从堂前石坪走进门，镜头淡入堂屋。书案和床榻分别接入每日研读和今夜安排，南门回到原来的石坪。屋内可以打开封地舆图，当前位置标在堂前。睡前点「找待浇田」后，金色指引在出门时出现。
- 堂屋随封地载入，共用时辰和日结算。屋内的手动档和床边生成的晨间档都从床榻旁继续。木地板有对应的脚步声，谷雨进屋会收起雨线并降低雨声。 [地形说明](../docs/game_design/06_地形系统_完整.md) · [暮色中的堂屋](../build/polish-hall-interior/final-frames/1280x720/02-room-at-dusk.png) · [晨间续档](../build/polish-hall-interior/final-frames/1280x720/05-morning-inside.png)
- 专项在新档种了公田和私田，暂派渠伯收割，以保留一格缺水的私田。按指引补水后恢复浇水职责。床边过夜后两格各长一阶、粮仓扣一份，从标题续档后两格可继续长成并分别收入国库和私仓。第六天走门槛往返核对谷雨。1280×720 与 1024×768 的 Vulkan 回放均在不可见的隔离桌面完成。 [Windows 试玩包](../build/polish-hall-interior/Fiefdom-hall-interior-preview-Windows-x64.zip) · [实机校验](../build/polish-hall-interior/final-frames/manifest.txt) · [Windows 发行验证](../build/polish-hall-interior/windows-release-check.log)
- Godot 4.7.2 导入、脚本加载、启动和 50 项自动回归通过。解压后的同一个 Windows 包通过堂屋专项、两种备粮方式的双结局、战败恢复、初税亩研究和三份旧档接续。完整人工长线试玩待验收。 [Godot 回归](../build/polish-hall-interior/godot-final-50.log)

## 从桑田走到蚕棚和西廊

- 蚕室建成后可从蚕桑页指路到门前。棚内三处工位共用原有的蚕桑库存和用料。蚕匾显示开养进度，缫丝车转动，织机走梭并显示织好的绸。棚内存档从门内继续，上一版在堂屋存下的档案仍从床边继续。旧档田渠占住棚址时可在蚕桑页继续工序。 [桑蚕规则](../docs/game_design/02_核心机制.md#桑蚕产业链) · [缫丝画面](../build/polish-silk-shed/rendered/1280x720/03-reeling.png)
- 专项从标题新开一局，按默认配方耕作和研读。第 3 天用 25 铜钱建蚕室，第 5 天开始养蚕并在棚内存读档，回堂屋过夜。第 7 天用两只茧缫丝织出一匹，第 9 天亲自走到西廊交样绸，收到 45 铜钱。两种窗口尺寸都在不可见的独立桌面取帧。 [织成第一匹](../build/polish-silk-shed/rendered/1280x720/04-first-bolt.png) · [西廊交样](../build/polish-silk-shed/rendered/1280x720/05-sample-delivered.png) · [实机校验](../build/polish-silk-shed/rendered/manifest.txt)
- Godot 4.7.2 导入、脚本加载、启动和 51 项自动回归通过。解压后的同一 Windows 包通过蚕棚专项、手动与委派备粮的双结局、战败恢复、初税亩研究和三个旧版本的存档接续。完整人工长线试玩待验收。 [Windows 试玩包](../build/polish-silk-shed/Fiefdom-silk-shed-preview-Windows-x64.zip) · [Godot 回归](../build/polish-silk-shed/godot-final-51.log) · [Windows 发行验证](../build/polish-silk-shed/windows-release-check.log)

## 田口、蚕棚和关道的同框比例

- 以 16×16 田格、20×27 站姿和 14×14 脚底碰撞校准户外比例。第一块井田的土径和田埂缺口统一为 16 像素。蚕棚净门洞扩到 22×28 像素并对齐墙体留口，南路亭抬高檐口并加宽到前阶的支路。 [美术规格](../docs/game_design/11_美术音效需求.md#封地的同框比例) · [同机位对照](../build/polish-map-scale/proportion-comparison.png)
- 东关与竹涧西门的关柱各在一侧路肩，碰撞落在石基，切图落在柱间土路。两种窗口尺寸在不可见的隔离桌面完成正常行走和往返取帧。 [实机回放日志](../build/polish-map-scale/rendered/1280x720/render.log)
- Godot 4.7.2 导入、脚本加载、启动和 51 项自动回归通过。Windows 包通过两种备粮方式的双结局和三个旧版存档接续。完整人工长线试玩待验收。 [Windows 试玩包](../build/polish-map-scale/Fiefdom-map-scale-preview-Windows-x64.zip) · [Godot 回归](../build/polish-map-scale/godot-final-51.log) · [Windows 发行验证](../build/polish-map-scale/windows-release-check.log)

## 西市的三处交易

- 封地舆图和管理市场可以指路去西市。沿西路过关柱可到石板街，走到粮摊、鱼摊或绸摊前按 E 交易。三个摊位分别接入现有的作物交易、溪鱼簿和售绸记录，时辰和物资与封地共用。 [西市实机](../build/polish-west-market/rendered/1280x720/01-west-market.png) · [窄窗口粮摊](../build/polish-west-market/rendered/1024x768/02-grain-counter.png)
- 专项从新档耕作到第三天，用收获的私田作物完成卖出、转粮和购粮，并用准备好的鱼、绸验证结算。市集保存后从标题继续，角色落在东口，走回封地仍有原来的国库和选种。两种窗口尺寸都在不可见的隔离桌面完成同一段回放。 [市集专项](../build/polish-west-market/godot-final-market.log)
- 同一 Windows 包通过双结局、战败恢复、初税亩研究、0.1.0 和上一版比例样板的存档接续。完整人工长线试玩待验收。 [Windows 试玩包](../build/polish-west-market/Fiefdom-west-market-preview-Windows-x64.zip) · [Windows 发行验证](../build/polish-west-market/windows-release-check.log)

## 从西市接单到私田收成

- 西市石板街南侧新增时令交货车。交货簿列出仓内缺额、已种的私田、今日新播的最早收成日和下季的渠水需求。可把当前单跟踪到种子栏上方，备齐后点条目指路去西市。西市和南路亭共用收据，交齐的货能在车上看到。 [交货簿](../build/polish-market-orders/rendered/1280x720/01-order-plan.png) · [田边跟踪](../build/polish-market-orders/rendered/1280x720/02-tracker-at-farm.png)
- 新档在第 1 天到西市看单，从标题续档后在私田种菽和黍，第 3 天亲自交货领 5 份口粮。另种的公田黍入国库。交货后续档仍能看到货车上的货，返封地时跟踪已收起。两个窗口尺寸均在不可见的隔离桌面完成回放。 [装车画面](../build/polish-market-orders/rendered/1280x720/04-loaded-cart.png) · [窄窗口收据](../build/polish-market-orders/rendered/1024x768/03-delivery-receipt.png)
- 导入、脚本加载、启动和 9 项相关回归通过，包含四季交货和夜间备粮。同一 Windows 包通过双结局及 0.1.0 和上一版西市存档接续。完整人工长线试玩待验收。 [Windows 试玩包](../build/polish-market-orders/Fiefdom-market-orders-preview-Windows-x64.zip) · [Godot 回归](../build/polish-market-orders/godot-order-suite.log) · [发行验证](../build/polish-market-orders/windows-release-check.log)

## 申禾的时令送货

- 交货后，申禾在酉时沿西路送货到南路亭。酉时以后交的货排到次日辰时。交货簿显示等候、在途和到货，玩家可以跟车过关，在亭前按 E 问这批货送给谁。两张地图用同一个时辰计算货车的位置。 [西路货车](../build/polish-season-freight/rendered/1280x720/06-estate-road.png) · [到货对白](../build/polish-season-freight/rendered/1024x768/07-south-pavilion.png)
- 新档第 3 天用私田收成在西市交货，获得 5 份口粮，公田的 1 份作物仍进国库。回放跳过等待时辰，核对出发、跨图、途中续档和到亭交谈。春末晚交的货在第 7 天辰时发出。上一版 Windows 生成的收据按交货当日酉时接续。 [Godot 回归](../build/polish-season-freight/godot-freight-suite.log) · [隔离桌面回放](../build/polish-season-freight/rendered/1280x720/render.log)
- 导入、脚本加载、启动和 8 项相关回归通过。1280×720 和 1024×768 的 Vulkan 回放均在不可见的隔离桌面完成。解压后的 Windows 包通过双结局、战败恢复、初税亩研究和两份旧版存档接续。完整人工长线试玩待验收。 [Windows 试玩包](../build/polish-season-freight/Fiefdom-season-freight-preview-Windows-x64.zip) · [发行验证](../build/polish-season-freight/windows-release-check.log)

## 南路灶台和随身路餐

- 交过第一张时令单后，沿南路亭南面的小径向东可到开火的灶台。申禾和舆图都可以指路。首轮取帧发现指路标签盖住灶台前的人物，现到台前站位时自动收起，只留按 E 的提示。 [修正前](../build/polish-travel-meals/rendered/1280x720/08-lit-hearth.png) · [修正后](../build/polish-travel-meals/final-frames/1280x720/08-lit-hearth.png) · [窄窗口配方](../build/polish-travel-meals/final-frames/1024x768/09-hearth-recipes.png)
- 从新档用私田的菽和黍交完春单，剩下的两份作物第 3 天装成菽黍饭。回放跳过等车时段，实际沿小径走到灶台。续档、过夜后包里仍有饭，第 4 天在田边有体力缺口时按 F 食用。公田作物仍收入国库。 [田边路餐](../build/polish-travel-meals/final-frames/1280x720/10-carried-meal.png)
- 稻鱼羹用预置的稻和鱼验证。灶台扣一份稻和菜单所示的一尾鲫鱼，保留鲤鱼和首获记录。穿过东关后点击随身按钮，体力由 47 恢复至 65，气血由 55 恢复至 83。上一版交货收据可以开启灶台。 [竹涧路餐](../build/polish-travel-meals/final-frames/1024x768/11-soup-at-ravine.png) · [Godot 回归](../build/polish-travel-meals/godot-travel-meal-suite.log)
- 导入、脚本加载、启动及 7 项相关回归通过。1280×720 和 1024×768 均用最终 Windows 包在不可见的隔离桌面完成回放。该包通过两条结局、战败恢复、研究期限和两份旧版存档接续。完整人工长线试玩待验收。 [Windows 试玩包](../build/polish-travel-meals/Fiefdom-travel-meals-preview-Windows-x64.zip) · [发行验证](../build/polish-travel-meals/windows-release-check.log)

## 历书与秋社

- 按 C 或点日历上的按钮可翻看本年四季的日期、轮访、天气、作物和时令单。谷雨与秋分在历书标出。秋分当天可从历书或舆图指路去展台。首轮取帧后挪开了被灶台屋檐挡住的展位，接上亭东小径，并对齐历书选中行的文字。 [历书](../build/polish-autumn-exhibit/final-frames/1280x720/01-almanac-autumn.png) · [修正前](../build/polish-autumn-exhibit/rendered/1280x720/03-autumn-exhibit.png) · [修正后](../build/polish-autumn-exhibit/final-frames/1280x720/03-autumn-exhibit.png)
- 新档从第 1 天查看秋分，种春单所需作物，交单补粮，持续收公田并用弓箭挡住第 9 天的敌袭。立秋再播稷，第 16 天以黍、菽、稷展出。从同一档分两次验证带回和分享。两种都给 30 点礼经验，分享扣三份私田作物并加 15 声望，国库原有六份纳贡保留。 [选样](../build/polish-autumn-exhibit/final-frames/1024x768/02-choose-samples.png)
- 续档保留展品和去向，过夜后展台收起，历书仍可翻到本年秋分查看。用第一年的实存收据和第 40 天测试档验证再次开办，商音会说出去年摆过的三样作物。 [展品记录](../build/polish-autumn-exhibit/final-frames/1280x720/04-exhibit-record.png) · [Godot 回归](../build/polish-autumn-exhibit/autumn-smoke.log)
- 秋季展品准备参考《星露谷物语》的集市，展台铜簋参考馆藏龙耳簋的方座与双耳。 [秋季展品规则](https://stardewvalleywiki.com/Grange_Display) · [馆藏龙耳簋](https://www.clevelandart.org/art/1974.73)
- Godot 导入、脚本加载、启动和 7 项相关回归通过。最终 Windows 包在不可见的隔离桌面完成 1280×720 与 1024×768 回放，同一包通过两条结局、战败恢复、研究期限及两份旧版存档接续。完整人工长线试玩待验收。 [Windows 试玩包](../build/polish-autumn-exhibit/Fiefdom-autumn-exhibit-preview-Windows-x64.zip) · [发行验证](../build/polish-autumn-exhibit/windows-release-check.log)

## 外出期间的门客田务

- 西市和竹涧在可活动时段推进门客浇水和收割，切图、交谈与暂停随时辰一起暂缓。先处理指派的田格。外出时每格基础用时为 3 秒，按门客效率调整。收获使用现有纳贡、计价、轮作和采叶结算。回封地先报格数，「今夜安排」列出入库入仓明细。打开面板时，地图提示收起。 [返程提示](../build/polish-away-field-work/final-frames/1280x720/02-return-to-estate.png) · [窄窗口田务明细](../build/polish-away-field-work/final-frames/1024x768/03-field-work-report.png)
- 专项用准备好的第 12 天存档验证实际过关。旧包到西市后两项田务仍未推进。新版途中保存并从标题继续后，共浇 2 格、收 3 格，入国库 1 份、私仓 3 份，得到 27 铜钱和 4 份桑叶。过夜消耗 3 份口粮，浇过水的幼苗长一阶，断水稻田停长。竹涧往返另验证浇水和收割各一格。 [旧包回放](../build/polish-away-field-work/previous-windows-replay.log) · [Godot 回归](../build/polish-away-field-work/away-field-smoke.log)
- 导入、脚本加载、启动及 10 项回归通过。最终 Windows 包在不可见的隔离桌面完成两种窗口尺寸回放，并通过两条结局、夜间备粮、战败恢复、研究期限及两份旧版存档接续。完整人工长线试玩待验收。 [Windows 试玩包](../build/polish-away-field-work/Fiefdom-away-field-work-preview-Windows-x64.zip) · [发行验证](../build/polish-away-field-work/windows-release-check.log)

## 从敌袭预告到第一次守田

- 用上一版 Windows 包从新档耕到第 8 天。和渠伯约好轮作后，轮作提示占用了原先的敌袭预告位置，「今夜安排」也没有守田信息。新版在封地手记中持续显示预告，点开可同看过夜田务、准备办法和射箭操作。 [旧版回放](../build/polish-raid-readiness/previous-windows-replay.log) · [轮作与敌袭预告同屏](../build/polish-raid-readiness/rendered/1280x720/01-raid-eve.png) · [窄窗口的过夜准备](../build/polish-raid-readiness/rendered/1024x768/02-preparation.png)
- 第 9 天出现野狗时，点封地手记上的警报可标出它的位置，标记随来敌移动。回放从晨间档继续，用右键射击击退野狗，两格成熟作物都保住了。作物被毁、兵家门客守卫及东岗守备牌预告斥候另有专项回归。 [来敌标记](../build/polish-raid-readiness/rendered/1280x720/03-marked-raider.png) · [防守结果](../build/polish-raid-readiness/rendered/1280x720/04-defense-result.png)
- 导入、脚本加载、启动及 10 项回归通过。同一个 Windows 包在不可见隔离桌面完成 1280×720 和 1024×768 键鼠回放，并通过两条结局、战败恢复、研究期限、夜间备粮和两份旧档接续。完整人工长线试玩待验收。 [Godot 回归](../build/polish-raid-readiness/raid-readiness-smoke.log) · [Windows 试玩包](../build/polish-raid-readiness/Fiefdom-raid-readiness-preview-Windows-x64.zip) · [发行验证](../build/polish-raid-readiness/windows-release-check.log)

## 第二块井田的施工备粮

- 「开垦备粮」报价合计立桩用粮和现有门客的四夜口粮，显示转粮品种和实际购粮开支。购粮会留出立桩的钱。从勘地进入市集可返回原田址，西市粮摊也可查看同一计划。专项验证了资金少 1 铜钱时，报价显示缺额并保留库存。改派收割岗位后，备粮目标按新粮耗更新。 [市场与开垦回归](../build/polish-construction-provisions/construction-provisions-smoke.log)
- 两版均从新档耕作、守田、晋升并招到三名门客。第 13 天从 29 份粮补到 72 份，换入 16 份、购入 27 份，购粮花 135 铜钱。旧版需要四次备粮操作并输入数量，新版一次确认。留出 140 铜钱立桩，付完立桩粮后余 12 份日粮，足够施工的四夜。第 17 天从晨间档继续，在新井田播种。 [旧版回放](../build/polish-construction-provisions/previous-windows-replay.log) · [新版回放](../build/polish-construction-provisions/construction-provisions-smoke.log)
- 首轮取帧发现守备消息压住市集页签。管理界面现在打开时收起地图消息，退出时恢复。勘地跳转会聚焦备粮报价。用同一个 Windows 包在不可见的隔离桌面完成 1280×720 和 1024×768 的开垦回放，并核对窄窗口西市粮摊的缺额报价。八种分仓库存的布局检查覆盖了换行。 [备粮报价](../build/polish-construction-provisions/final-frames/1280x720/06-construction-provisions.png) · [窄窗口收据](../build/polish-construction-provisions/final-frames/1024x768/07-provisions-receipt.png) · [西市粮摊](../build/polish-construction-provisions/final-stall-frames/1024x768/05-stall-provisions.png) · [分仓布局日志](../build/polish-construction-provisions/full-stock-market-layout.log)
- 资源导入、脚本加载、启动和 12 项相关回归通过。解压包通过传统与改革两条结局、战败恢复、研究期限、夜间备粮和两份旧档接续。完整人工长线试玩待验收。 [Windows 试玩包](../build/polish-construction-provisions/Fiefdom-construction-provisions-preview-Windows-x64.zip) · [发行验证](../build/polish-construction-provisions/windows-release-check.log)

## 第二年的四季托付

- 上一版 Windows 包的第二年重复第一年的四张订单。新版从第二个四季循环起使用新托付。春季「南路续种」可提前留一份冬麦，夏季「柳湾夏鲜」需两份稻和一尾白鲦，秋季「东岗换防」需稷、菽和麻，冬季「岁末麦帛」需两份麦和一匹丝绸。交货簿、历书和田边跟踪显示对应货物。 [上一版回放](../build/polish-second-year-orders/previous-windows-replay.log)
- 用准备好的季节存档，通过耕作、垂钓、养蚕缫丝和织绸备货。跨年当晚的备粮计划留出一份麦，第 25 天春单兑 7 份口粮。第 34 天亲自收稻、到柳湾钓白鲦后从西市交货，兑 7 份口粮。续档后到南路亭听申禾说下游修渠的人收到货。第 37 天用备好的稷、菽和麻交秋单，兑 26 铜钱。第 45 天用本季的麦和织成的丝绸交冬单，兑 51 铜钱。回放跳过等车时段。 [Godot 回归](../build/polish-second-year-orders/second-year-orders-smoke.log)
- 用上一版程序实际生成了第 36 天的未交夏单与已装车夏单。新版可以按旧要求继续，重复提交时保留原收据。过夜到第 37 天启用新秋单，旧夏单的车按原收据发车。 [Windows 专项回放](../build/polish-second-year-orders/packaged-year-orders.log)
- 导入、脚本加载、启动和 10 项相关回归通过。最终 Windows 包在不可见的隔离桌面通过 1280×720 和 1024×768 的键鼠回放，核对鱼与丝绸的货物图标、交货收据和申禾到亭对白。解压包通过双结局、战败恢复、研究期限、夜间备粮及两份旧档接续。完整人工长线试玩待验收。 [夏单到亭](../build/polish-second-year-orders/rendered/1280x720/05-summer-pavilion.png) · [窄窗口冬单](../build/polish-second-year-orders/rendered/1024x768/06-winter-wheat-and-silk.png) · [Windows 试玩包](../build/polish-second-year-orders/Fiefdom-second-year-orders-preview-Windows-x64.zip) · [发行验证](../build/polish-second-year-orders/windows-release-check.log)

## 井田逐格续播

- 在「管理 → 封地概览」选种并点击已翻的田格，可让照料门客在空畦上补播。田格显示现有作物和续播品种，稻种会等渠水接通。安排可改种或取消，随存档恢复。 [第一块井田](../build/polish-field-seed-plans/final-frames/1280x720/01-first-field-plans.png) · [第二块井田](../build/polish-field-seed-plans/final-frames/1024x768/02-second-field-plans.png)
- 预置第 32 天双井田档中，上一版收割后留下公田空畦。新版在西市期间收黍入国库并补播稷，回封地后存档里的稷继续生长。第 35 天再收一份公田纳贡，照原安排补播下一茬。专项也核对了亲手播种后的作物、已撤销的计划、桑树再生与稻田通水。 [上一版回放](../build/polish-field-seed-plans/previous-windows-replay.log) · [Godot 回归](../build/polish-field-seed-plans/seed-plan-smoke.log)
- 「今夜安排」的取帧曾在「铜钱」字间换行，已调整报表布局。资源导入、脚本加载、启动和 13 项相关回归通过。同一 Windows 包在不可见的隔离桌面跑过 1280×720 和 1024×768，并通过双结局、战败恢复、研究期限、夜间备粮和两个旧版存档接续。完整人工长线试玩待验收。 [修正前](../build/polish-field-seed-plans/rendered/1280x720/03-field-work-report.png) · [修正后](../build/polish-field-seed-plans/final-frames/1024x768/03-field-work-report.png) · [Windows 试玩包](../build/polish-field-seed-plans/Fiefdom-field-seed-plans-preview-Windows-x64.zip) · [发行验证](../build/polish-field-seed-plans/windows-release-check.log)

## 从第一畦公田到门客口粮

- 上一版的新档回放在公田浇水后提示过夜，收下第一份纳贡就显示晋升门槛。新版可在等公田生长时，从手记循地图标记去见当日来客。渠伯会在第一天说明新领采邑和公私田用途。首次纳贡后，尚未收过私田的玩家可循标记经营一格私田。应下渠伯的轮作后，翻好的空田会提示选菽。 [上一版回放](../build/polish-first-farm-days/previous-windows-replay.log) · [渠伯对白](../build/polish-first-farm-days/rendered/1280x720/04b-new-estate-conversation.png) · [窄窗口选种](../build/polish-first-farm-days/rendered/1024x768/09-choose-beans.png)
- 用默认规则从标题新开档，第一天浇水、见渠伯、保存并继续。第二天循手记找到季青，第三天收一份公田黍入库并与渠伯约好轮作。第五天收一份菽，留肥后从手记打开市场，查看转粮报价并确认，粮仓从 6 份增至 7 份。第六天结算一份门客口粮。另核对了已有私田作物的存档，继续时会指向已种的田格。 [窄窗口换粮](../build/polish-first-farm-days/rendered/1024x768/11-first-grain-trade.png)
- 导入、脚本加载和启动通过。全量回归更新了三处旧断言，覆盖现行的公田标签、管理时的地图消息和渠伯的开场对白。57 项场景均有通过记录。同一 Windows 包通过传统与改革两条结局、战败恢复、研究期限、夜间备粮及两份旧档接续，在不可见的隔离桌面完成两个窗口尺寸的开局回放。首次独立试玩和完整人工长线试玩仍待验收。 [场景清单](../build/polish-first-farm-days/scenario-coverage.txt) · [发行验证](../build/polish-first-farm-days/windows-release-check.log) · [Windows 试玩包](../build/polish-first-farm-days/Fiefdom-first-farm-days-preview-Windows-x64.zip)

## 西市石板街的昼夜

- 石板从三处摊前接到东侧关柱，玩家踩过石面和泥地时切换脚步声。谷伯、渔生和蔡娘会在柜台后理货，客人走到摊前时抬头。背筐伙计上午在粮摊西侧，巳时走到鱼摊南侧，傍晚向东出关。首轮取帧发现货车挡住伙计，已把停靠位置与车身错开。 [修正前](../build/polish-market-daylife/rendered/1280x720/00-market-morning.png) · [早市](../build/polish-market-daylife/final-frames/1280x720/00-market-morning.png) · [酉时出关](../build/polish-market-daylife/final-frames/1024x768/06-porter-at-dusk.png)
- 专项从新档耕到第 3 天，带预置的鱼和绸入市，完成三个摊位的交易。回放设置了酉时和戌时，验证伙计随时辰移动、设置暂停时停步、从标题继续时回到同一段路。入夜后，在灯下打开绸摊，再沿东路返回封地。两种窗口在不可见的隔离桌面取帧，并录下石板与泥地的实际脚步。 [夜市](../build/polish-market-daylife/final-frames/1024x768/07-market-lanterns.png) · [游戏脚步录音](../build/polish-market-daylife/final-frames/1280x720/stone-and-dirt.wav) · [录音出处](https://freesound.org/people/Fission9/sounds/521590/)
- 资源导入、脚本加载、启动及 12 项相关回归通过。同一 Windows 包通过双结局、战败恢复、初税亩研究、夜间备粮及 0.1.0 和上一版的存档接续。完整人工长线试玩仍待验收。 [Godot 回归](../build/polish-market-daylife/market-daylife-smoke.log) · [发行验证](../build/polish-market-daylife/windows-release-check.log) · [Windows 试玩包](../build/polish-market-daylife/Fiefdom-market-daylife-preview-Windows-x64.zip)

## 从封地舆图出发去竹涧

- 封地舆图的「竹涧」页显示野果、野药、两处钓点和东岸风险。选中地点后标记先指东关，切图后接上竹涧山路。路线可取消，出发前的目的地会随续档恢复。 [出发前查看舆图](../build/polish-ravine-trip/rendered/1280x720/02a-ravine-forecast.png) · [进入竹涧后查看路线](../build/polish-ravine-trip/rendered/1280x720/02b-willow-route.png)
- 新档专项选望溪台、取消并重选，保存后从标题继续，实际跨过东关和木桥走到野药旁。该回放暂停了野外敌人的行动，验证满气血取药仍保留当天采集次数。第二年夏单从预置的第 31 天档开始，收两份稻，在交货簿点「去柳湾钓白鲦」，第 34 天实际耗 5 点体力钓鱼并去西市领 7 份口粮。 [Godot 回归](../build/polish-ravine-trip/ravine-trip-smoke.log) · [垂钓](../build/polish-ravine-trip/rendered/1280x720/03-willow-catch.png) · [窄窗口收据](../build/polish-ravine-trip/rendered/1024x768/04-summer-receipt.png)
- 导入、脚本加载、启动及 12 项相关回归通过。同一 Windows 包在不可见的隔离桌面通过 1280×720 和 1024×768 的 Vulkan 回放，并通过两条结局、战败恢复、初税亩研究、夜间备粮及 0.1.0 和上一版存档接续。完整人工长线试玩仍待验收。 [Windows 试玩包](../build/polish-ravine-trip/Fiefdom-ravine-trip-preview-Windows-x64.zip) · [发行验证](../build/polish-ravine-trip/windows-release-check.log)

## 召简到堂前议税

- 上一版达标后立即暂停并打开议税面板。现在召简从东侧道路走到堂前。封地手记和舆图人物页可指路，靠近后按 E 看三案。玩家可离席再来，当天议税后可过夜。存档未定案时，续档可到堂前见召简。 [上一版回放](../build/polish-envoy-visit/previous-windows-replay.log) · [使者来访](../build/polish-envoy-visit/final-frames/1280x720/02b-envoy-arriving.png) · [人物页指路](../build/polish-envoy-visit/final-frames/1024x768/00-envoy-on-map.png)
- 用预置的第三年封地档验证离席、续档和实际收成。该专项暂停门客走动、延后敌袭，以核对收成和粮耗。支持改革后，该批成熟作物实际增加 4 份私仓、28 铜钱和 4 片桑叶，季青离开后每夜用粮从 4 降至 2。暂缓后，第 51 天欠 13 铜钱时召简回到堂前，改选传统并收成，国库和私仓分别增加 2 和 3 份。研究经费充足时，24 天实扣 1,200 铜钱，期满后在堂前看到最终两案。 [Godot 回归](../build/polish-envoy-visit/envoy-visit-smoke.log) · [经费不足时的两案](../build/polish-envoy-visit/final-frames/1024x768/03-final-research-choice.png)
- 首轮图形回放发现过夜提示盖住开场白，已修正并在两个窗口尺寸核对。导入、脚本加载、启动及 9 项相关回归通过。最终 Windows 包在不可见的隔离桌面完成回放，并通过从新档到第 56 天传统结局和第 59 天改革结局、战败恢复和两个旧版存档接续。完整人工长线试玩待验收。 [修正前](../build/polish-envoy-visit/rendered/1024x768/01-three-options.png) · [修正后](../build/polish-envoy-visit/final-frames/1024x768/01-three-options.png) · [Windows 试玩包](../build/polish-envoy-visit/Fiefdom-envoy-visit-preview-Windows-x64.zip) · [发行验证](../build/polish-envoy-visit/windows-release-check.log)

## 各局封地独立存档

- 上一版回放中，第一局四份存档被第二局的三次过夜和一次手动保存覆盖。现在每局各有三个轮换自动档和一个手动档。标题继续显示最新封地，选档页先选封地，再选晨间、议税或手动记录。设置默认打开本局，战败和结算从本局的可玩进度恢复。旧版记录可选读，继续后的存档归入同一局。 [上一版回放](../build/polish-estate-saves/previous-windows-replay.log) · [封地选择](../build/polish-estate-saves/final-frames/1280x720/10-second-estate.png)
- 专项设置第一局的第三年日期以验证初税亩。第二局「柳湾封地」用新档耕作，在第 3 天纳贡、手动保存，过夜至第 5 天。两局各保留四份。用最终 Windows 程序退出重启后，标题可继续第 5 天的新封地，再从选档页回到第 51 天的改革局。读取前后八份文件的 SHA-256 一致。 [重启回放](../build/polish-estate-saves/archive-restarted.log) · [校验清单](../build/polish-estate-saves/archive-restart-manifest.txt)
- 存档改动通过 58 项已有回归。首轮截图发现命名提示压到输入框，选中行的内边距也变窄。修正后重跑标题、晨间档、结局与议税，均通过。最终包在不可见的隔离桌面核对两个窗口尺寸，并通过双结局、战败恢复、夜间备粮、研究期限及两个旧版存档接续。完整人工长线试玩待验收。 [全量回归](../build/polish-estate-saves/estate-saves-smoke.log) · [最终界面回放](../build/polish-estate-saves/final-frames/1024x768/render.log) · [Windows 试玩包](../build/polish-estate-saves/Fiefdom-estate-saves-preview-Windows-x64.zip)

## 渠水、田缘与过路木板

- 水纹从水源沿通水渠向下游移动，经过弯角和分岔。通水渠与田缘之间画出进水口。渠线横穿土路时，木板落在路面交点，角色踩上去切换木质脚步声。首轮取帧发现进水口有一截被渠岸盖住，已接到渠面。 [上一版同机位](../build/polish-canal-flow/previous-frames/1280x720/02-connected.png) · [水纹动图](../build/polish-canal-flow/canal-water.gif)
- 专项从预置的第 9 天双井田档开始，延后敌袭。实际挖开水源旁的接头，两块田接水，沿路走过木板。填回接头后渠面和田缘变干，两格稻过夜停长。保存再读档，补接后两格在第 11 天各长一阶。 [填渠预览](../build/polish-canal-flow/final-frames/1024x768/04-preview-cutoff.png) · [断水](../build/polish-canal-flow/final-frames/1280x720/05-line-dry-again.png)
- 导入、脚本加载、启动及 12 项相关回归通过。最终 Windows 包在不可见的隔离桌面完成两个窗口尺寸的回放，并通过双结局、战败恢复、初税亩研究、夜间备粮及 0.1.0 和上一版存档接续。完整人工长线试玩待验收。 [Godot 回归](../build/polish-canal-flow/canal-flow-final-smoke.log) · [Windows 试玩包](../build/polish-canal-flow/Fiefdom-canal-flow-preview-Windows-x64.zip) · [发行验证](../build/polish-canal-flow/windows-release-check.log)

## 通关后继续经营封地

- 传统与改革的结局均可从当天继续经营。传统线在堂前西侧留下贡簿，改革线在南路亭留下新税册，两种记录均可从封地舆图指路。记录保留通关日期、账目和封地见闻。首轮取帧发现堂前贡簿遮住蚕棚屋檐和靠近的角色，已移到路旁空地。 [原位置](../build/polish-estate-after-ending/rendered/1024x768/traditional-record-stand.png) · [新位置](../build/polish-estate-after-ending/final-frames/1280x720/traditional-record-stand.png) · [新税册](../build/polish-estate-after-ending/final-frames/1024x768/reformed-record-read.png)
- 专项预置两条路线的通关条件和一格成熟作物。继续经营后，收割中央田在传统线增加 1 份国库，在改革线增加 1 份私仓。按 E 翻看记录时，仍显示通关当天的账目。专项同时核对了关闭自动保存时的行为。上一版 Windows 程序保存的两份通关档均能续营，原手动档的校验值一致。 [Godot 回归](../build/polish-estate-after-ending/ending-regression.log) · [旧通关档回放](../build/polish-estate-after-ending/legacy-ending-replay.log)
- 14 项 Godot 场景通过。最终 Windows 包从新档玩到第 56 天的传统结局和第 59 天的改革结局，续营后分别过夜至第 57 天与第 60 天，并从标题读回。同一包也通过战败恢复、研究期限、备粮和早期存档接续。两种窗口尺寸在不可见的隔离桌面取帧。首次独立试玩和完整人工长线试玩仍待验收。 [发行验证](../build/polish-estate-after-ending/windows-release-check.log) · [1024×768 图形回放](../build/polish-estate-after-ending/final-frames/1024x768/render.log) · [Windows 试玩包](../build/polish-estate-after-ending/Fiefdom-estate-after-ending-preview-Windows-x64.zip)

## 堂屋衣架与主角服饰

- 从堂前进屋，走到书案南侧的衣架按 E。两件布衣开局可换，晋升逐级开放麻衣、青绸、紫锦和裘衣，向陶辛交样绸可得西廊纹衣。可预览正面、侧面和背面。六套新增服饰的 54 张帧沿用原角色的脚底锚点，农具动作使用当前袖色。首轮取帧发现提示压到书案下沿，已移到衣架下方，并对齐选中和未选中时的列表图标。 [原提示位置](../build/polish-wardrobe/rendered/1280x720/07-sample-garment-worn.png) · [堂屋衣架](../build/polish-wardrobe/final-frames/1280x720/02-rust-in-hall.png) · [三向预览](../build/polish-wardrobe/final-frames/1024x768/01-brocade-preview.png) · [《星露谷物语》官方外观自定义说明](https://www.stardewvalley.net/about/)
- 换装专项预置声望和欠贡条件，再用正常过夜晋升、换麻衣、手动保存并从标题读回。走过西市路口后仍穿着麻衣。样绸专项从新档实际种桑、养蚕和织绸，第 9 天在西廊交样后回堂屋穿上纹衣。上一版 Windows 程序生成的堂屋存档可用初始布衣继续，原手动档的校验值一致。 [西市跨图](../build/polish-wardrobe/final-frames/1280x720/05-hemp-at-market.png) · [第 9 天的西廊纹衣](../build/polish-wardrobe/final-frames/sample-1280x720/06-sample-garment.png) · [旧档回放](../build/polish-wardrobe/legacy-wardrobe-replay.log)
- 资源导入、脚本加载、启动及 16 项 Godot 场景通过。最终 Windows 包通过双结局和续营、战败恢复、研究期限、备粮及早期存档接续。两种窗口尺寸在不可见的隔离桌面核对。首次独立试玩和完整人工长线试玩仍待验收。 [Godot 回归](../build/polish-wardrobe/wardrobe-regression.log) · [Windows 验证](../build/polish-wardrobe/windows-release-check.log) · [Windows 试玩包](../build/polish-wardrobe/Fiefdom-wardrobe-preview-Windows-x64.zip)

## 竹涧两岸的竹笼

- 从第二年起，钓获过鱼的玩家可在柳湾或砾滩下竹笼。黍饵一夜收一尾，菽饵两夜收两尾，鱼种取决于到期日的地点、季节与天气。两岸轮用一只笼。封地舆图优先显示已下的笼，过东关后指路接到干岸站位。首轮画面中角色挡住了笼桩，现已把站位和缆绳的系点错开。 [下笼预报](../build/polish-creek-traps/final-frames/1280x720/01-bait-forecast.png) · [舆图指路](../build/polish-creek-traps/final-frames/1024x768/03-ready-on-map.png) · [《星露谷物语》官方蟹笼与季节鱼种说明](https://www.stardewvalley.net/about/)
- 专项预置第 35 天、与蒲宁相识和两份饵料，并暂停竹涧敌人的行动。用真实抛竿钓到第一尾后，在砾滩用菽下笼，从封地保存、续档并过夜两次。第 37 天采过野果后回到砾滩，收了两尾鳜鱼。第 38 天在柳湾收一尾鲫鱼。回封地后通过溪鱼簿把一尾鳜鱼换成 5 份口粮。上一版 Windows 程序保存的第 35 天鱼获可继续，并开放两岸笼桩。 [收笼画面](../build/polish-creek-traps/final-frames/1280x720/04-ready-to-collect.png) · [溪鱼换粮](../build/polish-creek-traps/final-frames/1024x768/06-fish-to-rations.png) · [中期旧档回放](../build/polish-creek-traps/legacy-midgame-replay.log)
- 资源导入、脚本加载、启动及 14 项 Godot 场景通过。同一 Windows 包通过双结局、续营、战败恢复、初税亩研究、夜间备粮和旧档接续。两个窗口尺寸均在不可见的隔离桌面完成图形回放。首次独立试玩和完整人工长线试玩仍待验收。 [Godot 回归](../build/polish-creek-traps/trap-regression.log) · [Windows 验证](../build/polish-creek-traps/windows-release-check.log) · [Windows 试玩包](../build/polish-creek-traps/Fiefdom-creek-traps-preview-Windows-x64.zip)

## 秋社来客与分收成

- 阿绥、林蓼和禾伯早上沿亭东小路陆续到场，傍晚到草席和灯旁。封地图可以按名字指路，走近后按 E 交谈。角色沿用现有地图精灵尺寸和脚底排序。首轮取帧时，林蓼的取样路线经过展台入口，接管了 E 提示。把取样站位放到台前两侧后，玩家站在中间仍可翻展台簿。 [乡邻到场](../build/polish-autumn-gathering/final-frames/1280x720/00-arrival.png) · [分收成](../build/polish-autumn-gathering/final-frames/1280x720/05-first-handoff.png) · [《星露谷物语》官方节庆和居民日程说明](https://www.stardewvalley.net/about/)
- 带回的展品短暂陈列。分享可在来客到齐前提交，展品先摆在台上，到齐后按选择顺序各取一份。展台簿写明各份作物的去向。续档时按收据和时辰恢复展台及来客，次年交谈会提到去年收到的作物。 [傍晚灯下](../build/polish-autumn-gathering/final-frames/1280x720/06-festival-dusk.png) · [与禾伯交谈](../build/polish-autumn-gathering/final-frames/1024x768/07-harvest-dialogue.png)
- 专项从新档耕作、缴公粮并击退敌袭，到第 16 天用同一份存档回放两种选择。切到当天几个时辰核对来客和灯光，预置第 40 天以核对首年收据带来的回访。12 项 Godot 场景通过。Windows 包通过双结局、续营、战败恢复、研究期限、备粮和旧档接续。两个窗口尺寸的图形回放均在不可见的隔离桌面完成。完整人工长线试玩待验收。 [Godot 回归](../build/polish-autumn-gathering/autumn-final-smoke.log) · [图形回放](../build/polish-autumn-gathering/final-frames/1024x768/render.log) · [发行验证](../build/polish-autumn-gathering/windows-release-check.log) · [Windows 试玩包](../build/polish-autumn-gathering/Fiefdom-autumn-gathering-preview-Windows-x64.zip)

## 西坡羊棚与羊毛短衣

- 首次纳贡后，西市绸摊可花 100 铜钱领羊立栏。羊在暖季晴天放牧，傍晚回棚，雨天和冬季用草料。羊棚和「今夜安排」会显示缺草。绸摊售草料，羊棚也可用一份私仓麦备三份。十个饱食夜剪一份羊毛，可卖 36 铜钱，或凑两份让蔡娘织羊毛短衣。 [羊棚](../build/polish-sheepfold/final-frames/1280x720/05-wool-ready.png) · [过冬](../build/polish-sheepfold/final-frames/1280x720/04b-winter-sheep.png) · [堂屋试衣](../build/polish-sheepfold/final-frames/1024x768/08-wardrobe.png)
- 羊棚设在可开垦范围以南。首轮回放发现路尾贴着围栏，按键提示也压到羊身上。入口已加宽并与南路接顺，提示放到棚顶上方。长毛绵羊与剪毛时的录音采用 CC0 素材，游戏驱动走动、低头和短毛形态。 [首轮画面](../build/polish-sheepfold/rendered/1280x720/05-wool-ready.png) · [绵羊像素图](https://freegamesprites.com/en/assets/farm-sheep) · [羊叫录音](https://commons.wikimedia.org/wiki/File:Sheep_bleat.ogg) · [《星露谷物语》的农场与畜养](https://www.stardewvalley.net/about/)
- 专项从新档完成首次纳贡，再预置第 18 天、资金、声望和粮仓，并延后敌袭。第 22 夜缺草时羊毛停长，实际收下的私田麦补足草料后继续生长，公田麦入国库。第 29 天剪毛后回放出售与保留两种选择，第 39 天剪第二份，做衣、试穿并续档。14 项 Godot 场景通过，最终 Windows 包通过双结局、续营、战败恢复、研究期限、备粮和旧档接续。两个窗口尺寸均在不可见隔离桌面回放。完整人工长线试玩待验收。 [Godot 回归](../build/polish-sheepfold/sheepfold-final-smoke.log) · [图形回放](../build/polish-sheepfold/final-frames/1024x768/render.log) · [发行验证](../build/polish-sheepfold/windows-release-check.log) · [Windows 试玩包](../build/polish-sheepfold/Fiefdom-sheepfold-preview-Windows-x64.zip)

## Windows 手柄操作

- 按 Xbox 布局显示键位。左摇杆或十字键走路，右摇杆移动准星。A 确认或耕作，按住 A 移动准星可在同一块井田连耕。手柄复用现有按钮、地图与农事输入。封地手记、舆图和野外操作提示随输入设备切换。 [Godot 控制器输入](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html) · [Godot Viewport 输入](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-push-input)
- 首轮画面中，纳贡通知盖住「保存游戏」。设置打开时已隐藏这条通知。最终包在 1280×720 和 1024×768 的不可见隔离桌面检查了田格准星、舆图、设置、确认框和垂钓画面。 [修正前](../build/polish-gamepad/initial-settings.png) · [修正后](../build/polish-gamepad/final-frames/1280x720/03-settings.png) · [竹涧](../build/polish-gamepad/final-frames/1024x768/06-fishing.png)
- 旧 Windows 包收到 A 键输入时未开局或翻地。最终包用模拟手柄从新档玩到第 3 天，公私田各收一份并分别入仓，私田另得 5 铜钱。为固定收成测试，暂时停用渠伯自动浇田。挖渠、填渠和钓鱼用预置进度验证。16 项 Godot 场景通过，同一 Windows 包通过双结局、续营和旧档接续。实体手柄手感与完整人工长线试玩待验收。 [旧包回放](../build/polish-gamepad/previous-windows-replay.log) · [Godot 回归](../build/polish-gamepad/gamepad-final-smoke.log) · [发行验证](../build/polish-gamepad/windows-release-check.log) · [Windows 试玩包](../build/polish-gamepad/Fiefdom-gamepad-preview-Windows-x64.zip)

## 冬至南路亭围炉

- 历书可提前查看冬至日期、食材和去处。冬至首日，禾伯在南路亭东接食材，阿绥与林蓼沿路赴席，酉时桌边点灯。麦和菽可煮麦菽粥，最多供当晚门客 3 份。麦和溪鱼可煮鱼麦羹，最多供 5 份。菜单列出冬单也需要的麦，玩家可按自家用粮选择。历书和次年对白保留这次备饭。 [历书](../build/polish-winter-supper/final-frames/1280x720/01-almanac.png) · [酉时到场](../build/polish-winter-supper/final-frames/1280x720/03-lanterns.png) · [《星露谷物语》官方季节节庆介绍](https://www.stardewvalley.net/about/)
- 首轮实画面中，第三行用料被对话按钮遮住，左侧来客与竹丛重叠。对话面板现在按正文高度展开，来客移到桌后的空地，两盏灯在酉时已亮。1280×720 和 1024×768 均在不可见的隔离桌面核对了来客、用料和夜间账目。 [修正前](../build/polish-winter-supper/initial-supper-choice.png) · [窄窗口修正后](../build/polish-winter-supper/final-frames/1024x768/04-supper-choice.png) · [Godot 正文尺寸 API](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html#class-richtextlabel-method-get-content-height)
- 自动回放从新档耕种、钓鱼、招募，击退两次来敌后在第 22 天收齐食材。两位门客的收割岗当晚共需 4 份粮。粥供 3 份，夜间备粮转用 1 份菽。读回第 22 天改做鱼麦羹，围炉供齐 4 份。保存再继续后，晨间记录保留实际用量。取帧加快了当天时辰，次年对白用预置日期复核。18 项 Godot 回归通过，同一 Windows 包通过双结局、续营、战败恢复、研究期限及两份旧档接续。完整人工长线试玩待验收。 [今夜安排](../build/polish-winter-supper/final-frames/1024x768/05-tonight.png) · [Godot 回归](../build/polish-winter-supper/winter-supper-final-smoke.log) · [发行验证](../build/polish-winter-supper/windows-release-check.log) · [Windows 试玩包](../build/polish-winter-supper/Fiefdom-winter-supper-preview-Windows-x64.zip)

## 键盘键位

- 冬至预览包只有音量、全屏和自动保存等常规设置。标题和封地的「系统设置 → 键盘键位」现在可改 18 项。键位全局保存，两项都可使用对方的键时可以互换，可用 Esc 取消改键或在同一页恢复默认。方向键也能走路，通用菜单继续用方向键、回车、Tab 和 Esc。 [旧包回放](../build/polish-key-bindings/previous-windows-replay.log) · [Godot 输入映射](https://docs.godotengine.org/en/stable/classes/class_inputmap.html) · [键盘位置与本地标签](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-keyboard-get-label-from-physical)
- 封地手记、邻里互动、舆图、历书、路餐、种子栏和渠务提示随当前键位更新。初次回放发现改过的四个移动键连写难读，最终版用斜线分开，并为改键页加了独立标题。1280×720 和 1024×768 窗口均在不可见的隔离桌面核对了标题入口、改键、互换和封地内的设置。 [封地键位](../build/polish-key-bindings/final-frames/1280x720/06-estate-keyboard.png) · [窄窗口互换结果](../build/polish-key-bindings/final-frames/1024x768/03-reassigned.png)
- 自动回放从无键位设置的旧配置开局，经菜单更改 10 项，验证了移动、对话、选种、舆图、历书、路餐、挖填水渠、换弯和编钟。路餐和渠务使用预置进度，手柄使用模拟输入。Windows 程序重启后读取改键，再从设置恢复 18 项默认值，音量和自动保存设置均保留。20 项 Godot 回归通过，同一 Windows 包通过双结局、续营、战败恢复、研究期限和两份旧档接续。实体手柄与完整人工长线试玩待验收。 [Godot 回归](../build/polish-key-bindings/key-bindings-final-smoke.log) · [发行验证](../build/polish-key-bindings/windows-release-check.log) · [Windows 试玩包](../build/polish-key-bindings/Fiefdom-key-bindings-preview-Windows-x64.zip)

## 夏至竹涧试筏

- 封地在芒种末日提醒，历书可为夏至首日的试筏指路。走过东关，竹涧舆图把路线接到西岸新埠头。玩家在柳湾一带控筏顺流，穿过四道交替排列的竹标，到木桥前结算。先比较过标数，道数相同再比较用时。每年首次过三道并抵达终点可得 30 点御经验。最佳成绩随本局存档保存，过节后可到埠头翻筏簿。 [旧包基线](../build/polish-summer-raft/previous-windows-replay.log) · [夏至历书](../build/polish-summer-raft/final-frames/1280x720/01-almanac.png) · [竹涧舆图](../build/polish-summer-raft/final-frames/1280x720/02-ravine-map.png) · [《星露谷物语》官方节庆介绍](https://www.stardewvalley.net/about/)
- 首轮取帧发现柳湾钓点文字挨着赛道，陆汀和主角站位重合。试筏时收起两个互动提示，将陆汀移到岸边空地，加宽筏身并标亮木桥前的终点线。筏身和水纹取自 Sevarihk 的无帆素材，发布包附作者与授权。最终包在 1280×720 和 1024×768 两种窗口尺寸下用不可见隔离桌面复核了过标、结算和筏簿。 [首轮过标](../build/polish-summer-raft/initial-steering.png) · [最终过标](../build/polish-summer-raft/final-frames/1280x720/04-steering.png) · [窄窗口结算](../build/polish-summer-raft/final-frames/1024x768/05-finish.png) · [原素材](https://opengameart.org/content/animated-pixel-art-raft-sprite)
- 专项从新档耕作到第 10 天，固定渠伯并延后敌袭，核对公田入国库和私田入仓后，经正常路口去试筏。直漂过两道，改键后可过四道，模拟手柄加快划水后以 5.66 秒过四道。取消会回到岸边，重复挑战只更新最佳。回封地存档、从标题继续，再过一夜，仍可在埠头看到成绩。20 项 Godot 回归通过，同一个 Windows 包通过双结局、续营、战败恢复、研究期限和两份旧档接续。实体手柄与完整人工长线试玩待验收。 [Godot 回归](../build/polish-summer-raft/summer-raft-final-smoke.log) · [发行验证](../build/polish-summer-raft/windows-release-check.log) · [Windows 试玩包](../build/polish-summer-raft/Fiefdom-summer-raft-preview-Windows-x64.zip)

## 标题里的封地

- 用游戏原场景取代旧标题的山形背景。2 倍斜俯视机位同时容纳堂屋、第一块井田和南路亭。取景时布置了成熟作物，并收起田务提示。清晨与薄暮用同机位的两张画面渐变，标题光线有独立的 42 秒循环。四字书法标题采用 Ma Shan Zheng 的字体子集，Windows 包附 SIL OFL 1.1 授权文本。 [旧标题](../build/polish-title-estate/survey/1280x720/01-title-before.png) · [旧包校验](../build/polish-title-estate/survey/source-runtime.txt) · [清晨](../build/polish-title-estate/final-frames/1280x720/01-morning-title.png) · [薄暮](../build/polish-title-estate/final-frames/1280x720/02-dusk-title.png) · [字体原项目](https://github.com/google/fonts/tree/main/ofl/mashanzheng)
- 空档时焦点落在「新建游戏」。有可读存档时，「继续游戏」列首项，下方写出将打开的封地、日期和来源。存档全部损坏时，标题可新建或进入选档查看。两种窗口尺寸均在不可见隔离桌面核对，窄窗口能显示完整的 16 字封地名，选档页右栏显示全名。 [窄窗口续档](../build/polish-title-estate/final-frames/1024x768/06-named-estate.png) · [选档](../build/polish-title-estate/final-frames/1024x768/07-save-picker.png)
- 专项以实画面和输入回放验证标题光线自动推进、封地时辰稳定、开局公私田分别结算、两局保存及继续最近一局。开局专项固定渠伯，手柄回归使用模拟输入。20 项 Godot 回归通过，同一个 Windows 包通过双结局、续营、战败恢复、研究期限和两份旧档接续。实体手柄与完整人工长线试玩待验收。 [Godot 回归](../build/polish-title-estate/title-final-smoke.log) · [发行验证](../build/polish-title-estate/windows-release-check.log) · [Windows 试玩包](../build/polish-title-estate/Fiefdom-title-estate-preview-Windows-x64.zip)

## 堂屋地席与窗下摆件

- 走到堂屋窗下的木案按 E，可在房间里预览地席和摆件。两处分别选好后点「应用陈设」，按 Esc 或手柄 B 可取消预览。首贡、钓鱼、通水查验、样绸和节令活动等本局记录会开放相应物件。住处可布置的思路参考《星露谷物语》，陈设像素图按堂屋现有比例绘制。 [陈设规则](../docs/game_design/09_元游戏系统.md#堂屋陈设) · [《星露谷物语》官方介绍](https://www.stardewvalley.net/about/)
- 首轮取帧后缩小了谷穗，让窗格留出更多空间。最终包在不可见的隔离桌面复核了 1280×720 和 1024×768 窗口里的两页陈设，以及读档后回到堂屋的画面。 [地席预览](../build/polish-hall-decor/final-frames/1280x720/04-blue-mat-preview.png) · [窄窗口摆件预览](../build/polish-hall-decor/final-frames/1024x768/03-tribute-preview.png) · [回到堂屋](../build/polish-hall-decor/final-frames/1280x720/05-return-to-hall.png)
- 专项从新档正常耕作，第 3 天公私田分别入库，首次公田收获开放谷穗。歇脚处使用已送路粮和备足铜钱的前置数据，出资后等一夜才开放青纹苇席。回放覆盖键盘及模拟手柄取消、两处分别应用、手动存档后从标题继续，以及新封地恢复默认陈设。上一版 Windows 程序写出的堂屋存档读回素苇席和空案，原档校验值一致。Godot 导入、脚本加载、启动及 18 项回归通过。同一 Windows 包通过双结局、续营、战败恢复、研究期限和两份旧档接续。实体手柄与完整人工长线试玩待验收。 [旧堂屋存档](../build/polish-hall-decor/legacy-hall-decor.log) · [Godot 回归](../build/polish-hall-decor/godot-final-18.log) · [发行验证](../build/polish-hall-decor/windows-release-check.log) · [Windows 试玩包](../build/polish-hall-decor/Fiefdom-hall-decor-preview-Windows-x64.zip)

## 议税后的结局目标

- 上一版在封地手记用一行数字显示路线。定案后现可点「结局目标」，逐项查看达成条件、进度和可用的操作入口。收成连到井田舆图，进献和售绸连到蚕桑，铜钱连到市场。守备入口随来敌时机切换，可打开门客分工、明日守备计划或标出来敌。 [上一版回放](../build/polish-route-goals/previous-windows-replay.log) · [封地手记](../build/polish-route-goals/final-frames/1280x720/01-reform-journal.png) · [传统路线](../build/polish-route-goals/final-frames/1280x720/04-traditional-goals.png)
- 专项预置第三年成熟作物、一匹绸和传统路线的来敌日期。回放实际走到召简面前定案，收割、售绸或进献，再买粮或过夜。改革线收入四份计税收成，卖绸后铜钱增至 150，买粮支出 5 后进度回落。传统线两格公田入库并进献一匹，过夜后可从目标页标出第 55 天的来敌。上一版真实议税自动档可继续，读取前后文件校验值一致。 [窄窗口售绸后](../build/polish-route-goals/final-frames/1024x768/03-silk-sold.png) · [明日守备](../build/polish-route-goals/final-frames/1024x768/05-raid-plan.png) · [旧议税存档](../build/polish-route-goals/legacy-route-goals.log)
- Godot 导入、脚本加载、启动与 15 项回归通过。最终 Windows 包在不可见的隔离桌面复核两个尺寸，并用新档分别在第 56 天和第 59 天走到结局。战败恢复、研究期限、续营和旧档接续通过。完整人工长线试玩仍待验收。 [Godot 回归](../build/polish-route-goals/godot-final-15.log) · [发行验证](../build/polish-route-goals/windows-release-check.log) · [Windows 试玩包](../build/polish-route-goals/Fiefdom-route-goals-preview-Windows-x64.zip)

## 新领采邑与首贡指路

- 新档进场时，封地手记短暂提示渠伯留下了交接简。玩家可立即耕作，也可读简查看中央公田、四周私田的收成去向，或循简上指路到渠伯身边。采用《星露谷物语》以接手农场交代开局缘由的思路，用《采邑春秋》的受封与井田串起第一天。 [交接简](../build/polish-arrival/final-frames/1024x768/01b-handover-note.png) · [翻地前给渠伯指路](../build/polish-arrival/final-frames/1280x720/01c-meet-keeper-before-farming.png) · [《星露谷物语》官方介绍](https://www.stardewvalley.net/about/)
- 上一版首贡后，手记提示种私田，金色标记却落到渠伯身上。现在收获数字停在刚收的田格上，下一步标出私田。想谈轮作时可点手记按钮。出门期间门客完成首贡时，回封地也会提示结果和轮作机会。 [上一版首贡画面](../build/polish-arrival/baseline-frames/1280x720/05-first-tribute-and-keeper.png) · [首贡入库与私田标记](../build/polish-arrival/final-frames/1280x720/05-first-tribute-and-keeper.png)
- 自动输入从标题新建，实际走过浇水、找渠伯、存档继续、首贡、轮作、私田换粮与第 6 天用粮。上一版写出的首日存档保留浇水状态，可读交接简，文件校验值一致。Godot 导入、脚本加载、启动及 17 项回归通过。最终 Windows 包验证双结局、续营、战败恢复和旧档，在不可见的隔离桌面复核 1280×720 与 1024×768 窗口。首次独立试玩和完整人工长线试玩待验收。 [旧首日档](../build/polish-arrival/legacy-first-day.log) · [Godot 回归](../build/polish-arrival/godot-final-17.log) · [发行验证](../build/polish-arrival/windows-release-check.log) · [Windows 试玩包](../build/polish-arrival/Fiefdom-arrival-preview-Windows-x64.zip)

## 私田批量续播与换季预览

- 「管理 → 封地概览」选种后可一次安排或取消当前井田的私田续播。上一版需要点八次的安排现在点一次即可完成。保留逐格调整，传统路线的公田、另一块井田和多年生作物各自保留原安排。选种菜单显示成熟所需夜数、当令和需渠水条件，换季前显示次日的变化。 [上一版回放](../build/polish-field-planning/previous-windows-replay.log) · [窄窗口播种预览](../build/polish-field-planning/final-frames/1024x768/01-before-summer.png) · [八格续播安排](../build/polish-field-planning/final-frames/1280x720/02-eight-private-plans.png)
- 专项从预置的第 30 天双井田档起步。谷雨当天播稻需四夜，过夜至立夏后需三夜。收下原有麦苗长成的一份麦，接通渠水后门客补播三夜稻种，缺水田格继续等待。当天核对公田和私田各入库一份、夜间消耗三份口粮。存档恢复后可批量清除八格计划，专项另用改革状态核对原中心格已计入九格私田。上一版实际保存的八格麦计划可继续，读取前后原文件校验值一致。 [通水后补播](../build/polish-field-planning/final-frames/1280x720/04-irrigated-summer-rice.png) · [旧井田计划](../build/polish-field-planning/legacy-field-plans.log)
- Godot 导入、脚本加载、启动和 16 项回归通过。同一 Windows 包在不可见的隔离桌面核对 1280×720 与 1024×768 窗口，并完成从新档到传统和改革结局的自动回放、续营、战败恢复与旧档接续。首次独立试玩和完整人工长线试玩待验收。 [Godot 回归](../build/polish-field-planning/godot-final-16.log) · [发行验证](../build/polish-field-planning/windows-release-check.log) · [Windows 试玩包](../build/polish-field-planning/Fiefdom-field-planning-preview-Windows-x64.zip)

## 陶辛带样绸去西市

- 上一版在同一份交样后的进度里，午时的陶辛仍在西廊，西市没有样绸陈列。新版在交付次日把样绸挂到蔡娘摊边，柜台注明封地名。晴天轮访从西廊出发，午、未时到西市绸摊，申时返程，酉时走到南路亭。封地舆图和邻里手记会标出西路。陶辛会谈起摊前样绸，也会认出玩家身上的西廊纹衣。 [上一版回放](../build/polish-silk-market/previous-windows-replay.log) · [邻里手记](../build/polish-silk-market/final-frames/1024x768/01-neighbor-journal.png) · [绸摊相见](../build/polish-silk-market/final-frames/1280x720/03-market-conversation.png) · [《星露谷物语》官方人物介绍](https://www.stardewvalley.net/about/)
- 专项从标题新建，正常收下首轮公私田，使用预备的一匹绸走完交样。第 9 天在几段路线开始前调到对应时辰，跟陶辛走过西路，用绸摊交谈、存档继续、返亭和留任验证角色去处。第 54 天雨天轮访使用预置日期，样绸照常陈列，陶辛留在封地。上一版程序写出的交样存档在新版恢复午时行程，原档文件校验值一致。 [旧样绸存档](../build/polish-silk-market/legacy-silk-sample.log) · [Godot 回归](../build/polish-silk-market/godot-final-verified-18.log)
- 首轮回放发现返亭路线碰到蚕棚后墙，取帧发现陶辛的名字压住布样。改走蚕棚东侧路缘，并把他在绸摊的站位移到街面。18 项 Godot 回归通过，最终 Windows 包在不可见的隔离桌面核对 1280×720 与 1024×768 窗口，且通过新档双结局、续营、战败恢复和旧档。完整人工长线试玩待验收。 [窄窗口绸摊](../build/polish-silk-market/final-frames/1024x768/04-silk-counter.png) · [沿西路返亭](../build/polish-silk-market/final-frames/1280x720/05-back-on-the-estate.png) · [发行验证](../build/polish-silk-market/windows-release-check.log) · [Windows 试玩包](../build/polish-silk-market/Fiefdom-silk-market-preview-Windows-x64.zip)

## 封地关道、北坡和田埂

- 上一版两条主路出关后在镜头内收尾，北侧行走止点没有地形。主路现在通到镜头之外，北坡用石垒和前后两层林木标出边界，舆图的道路裁在图幅内。新版实走西市和竹涧往返，向北走到石垒脚边停下。 [旧西路](../build/polish-estate-terrain/baseline-frames/1280x720/01-west-road.png) · [新西路](../build/polish-estate-terrain/final-frames/1280x720/01-west-road.png) · [北坡](../build/polish-estate-terrain/final-frames/1280x720/02-north-slope.png) · [舆图](../build/polish-estate-terrain/final-frames/1024x768/07-estate-survey.png)
- 土纹和路肩草丛取自 Pixel-Boy 与 AAA 的 CC0 图块，按季节和天气调色。首轮取帧后减淡土纹，并把低处的田边土层放到路面下，让田埂贴路时保留路肩。专项从新档播种和浇水，切图回来仍可查到水分。谷雨场景用预置的第二块井田和蚕棚，通过原水利入口建渠，复核进水口和横跨路面的木板。冬日场景以预置日期核对覆雪的北坡和井田。标题使用最终地形取景，清晨和薄暮使用同一机位和一块预置的成熟井田。 [谷雨通水](../build/polish-estate-terrain/final-frames/1024x768/03-rain-and-second-field.png) · [冬日北坡](../build/polish-estate-terrain/final-frames/1280x720/06-winter-slope.png) · [薄暮标题](../build/polish-estate-terrain/title-frames/1280x720/02-dusk-title.png) · [素材作者页](https://pixel-boy.itch.io/ninja-adventure-asset-pack)
- Godot 导入、脚本加载、启动及 22 项回归通过。最终 Windows 包在不可见的隔离桌面核对 1280×720 与 1024×768 窗口，并完成新档双结局、旧档接续和无窗口连续运行。完整人工长线试玩待验收。 [Godot 回归](../build/polish-estate-terrain/godot-delivered-22.log) · [发行验证](../build/polish-estate-terrain/windows-release-check.log) · [Windows 试玩包](../build/polish-estate-terrain/Fiefdom-estate-terrain-preview-Windows-x64.zip)

## 井田舆图与连续田务指路

- 上一版「今夜安排」只能指出一格待浇田。点种子栏的「田务」现可直达井田页，用方块、菱形和叉号区分可收、待浇和断水。选一类田务，完成当前格后自动指向下一格。第一轮取帧发现已浇田的悬停提示遮住下一格，现随指路前进收起旧提示。 [上一版回放](../build/polish-field-routes/previous-windows-replay.log) · [井田舆图](../build/polish-field-routes/final-frames/1024x768/01-field-map.png) · [下一格标记](../build/polish-field-routes/final-frames/1280x720/02-next-dry-plot.png)
- 专项从标题新建，正常播种两格，再预置第二块井田、部分作物长势和断开的水渠。实际浇水、收割和挖渠，核对公私田结算与体力消耗。同日读档后恢复待浇路线，去西市期间门客浇完最后一格，回封地保留外出回报。过夜结束当前指路，挖渠时仍能看见断水稻田标记。用上一版实际保存的两格黍读档，从「今夜安排」浇完公田后继续标私田，原档校验值一致。 [断水指路](../build/polish-field-routes/final-frames/1024x768/03-disconnected-rice.png) · [旧档回放](../build/polish-field-routes/legacy-field-routes.log)
- Godot 导入、脚本加载、启动及 20 项回归通过。同一 Windows 包在不可见的隔离桌面核对 1280×720 和 1024×768 窗口，自动验证两条结局、续营、战败恢复和旧档接续。首次独立试玩和完整人工长线试玩待验收。 [Godot 回归](../build/polish-field-routes/godot-field-routes.log) · [发行验证](../build/polish-field-routes/windows-release-check.log) · [Windows 试玩包](../build/polish-field-routes/Fiefdom-field-routes-preview-Windows-x64.zip)

## 门客收工后到南路亭歇脚

- 上一版到戌时，渠伯仍在白天的岗位上。晴天酉时后，做完田务的具名门客会沿南路到亭东席案。遇雨或来敌时收起席案，守卫值岗。邻里手记和舆图按实际位置指路。席间有各人的日常对白，到席案南侧可以查看今夜口粮。首轮取帧中人物重叠，最终将席位分开。 [上一版回放](../build/polish-pavilion-evening/previous-windows-replay.log) · [亭前灯火](../build/polish-pavilion-evening/final-frames/1280x720/04-pavilion-lanterns.png) · [窄窗口对白](../build/polish-pavilion-evening/final-frames/1024x768/05-evening-conversation.png) · [《星露谷物语》官方角色日程介绍](https://www.stardewvalley.net/about/)
- 专项从新档播种，经由席案过夜并验证作物生长和口粮消耗。渠伯先完成原有田务，歇脚时遇到新播的干田也会回去浇水。次日预置招募所需声望与守卫，实际招募季青并验证两人的位置。回放加快日照，并预置雨天和敌袭状态。标题续档、实际走西关往返和上一版戌时存档均恢复了晚间去处，旧存档文件的校验值一致。 [口粮面板](../build/polish-pavilion-evening/final-frames/1024x768/02-table-rations.png) · [旧档回放](../build/polish-pavilion-evening/legacy-pavilion-evening.log)
- Godot 导入、脚本加载、启动及 22 项回归通过。最终 Windows 包在不可见隔离桌面核对 1280×720 和 1024×768 窗口，另通过双结局、续营、战败恢复及旧档接续。首次独立试玩和完整人工长线试玩待验收。 [Godot 回归](../build/polish-pavilion-evening/godot-pavilion-evening.log) · [发行验证](../build/polish-pavilion-evening/windows-release-check.log) · [Windows 试玩包](../build/polish-pavilion-evening/Fiefdom-pavilion-evening-preview-Windows-x64.zip)

## 西市鱼摊的四季留鱼单

- 上一版鱼摊只按常价收鱼。渔生现在每季为顾客留一种鱼，到摊前交一尾可选铜钱或口粮。溪鱼簿显示截止日和报价，可指路去钓点或西市。第二年夏天，最后一尾白鲦同时能交「柳湾夏鲜」时，两个面板都会提醒。完成交鱼后，摊前木牌转亮。首轮取帧中鱼摊面板贴近屏幕上下边，最终放宽面板并单独标出留鱼提示。 [旧版报价](../build/polish-fish-market-orders/previous-windows-replay.log) · [鱼摊报价](../build/polish-fish-market-orders/final-frames/1024x768/04-fish-stall-offer.png) · [时令单提示](../build/polish-fish-market-orders/final-frames/1280x720/03-last-minnow-at-cart.png) · [《星露谷物语》公告栏委托更新记录](https://www.stardewvalley.net/stardew-valley-1-4-update-full-changelog/)
- 专项预置第 35 天、与蒲宁相识和两份稻，暂停了竹涧敌人的行动。玩家实际从柳湾钓两尾白鲦，分别在两天交鱼摊和「柳湾夏鲜」。第 35 天鱼摊支付 13 铜钱，回执可从标题继续。过夜入秋后，玩家走过木桥到砾滩钓鳜鱼，交鱼换 7 份粮。上一版保存的鲤鱼存档保留鱼获并开放春单，旧档校验值一致。 [西市续档](../build/polish-fish-market-orders/windows-verification/fish-market-orders.log) · [秋季口粮收据](../build/polish-fish-market-orders/final-frames/1024x768/08-autumn-receipt.png) · [旧档回放](../build/polish-fish-market-orders/legacy-fish-market-orders.log)
- Godot 导入、脚本加载、启动及 22 项回归通过。最终 Windows 包在不可见隔离桌面核对 1280×720 和 1024×768 窗口，并通过双结局、续营、战败恢复和旧档接续。首次独立试玩和完整人工长线试玩待验收。 [Godot 回归](../build/polish-fish-market-orders/godot-fish-market-orders.log) · [发行验证](../build/polish-fish-market-orders/windows-release-check.log) · [Windows 试玩包](../build/polish-fish-market-orders/Fiefdom-fish-market-orders-preview-Windows-x64.zip)

## 瞄准野狗与斥候

- 上一版 Windows 包进入竹涧后，右键点斥候帽子，气血仍为 30。点脚下则扣掉 10 点。新版指针压到敌人的可见轮廓时显示脚边角标，箭朝它当时的地面位置飞。瞄向空地可以提前射击，斥候侧移能躲开已离弦的箭。 [旧版回放](../build/polish-bow-aim/previous-windows-replay.log) · [鼠标瞄准与命中](../build/polish-bow-aim/final-frames/1280x720/02-scout-hit.png) · [Godot 精灵像素检测](https://docs.godotengine.org/en/4.6/classes/class_sprite2d.html#class-sprite2d-method-is-pixel-opaque)
- 竹涧专项走东关进入地图，把斥候摆在与玩家同一高度并暂停两名敌人的行动，固定对照帽子和脚下的箭路。实际回放用右键命中，再放大镜头，用右摇杆和 RT 命中。封地专项从新档正常耕作到第 9 天，瞄准移动野狗的耳朵射退它，公田和私田的两格成熟作物都保住了。 [窄窗口手柄准星](../build/polish-bow-aim/final-frames/1024x768/03-controller-target.png) · [守田与战斗回归](../build/polish-bow-aim/godot-bow-aim.log)
- Godot 导入、脚本加载、启动及 21 项回归通过。同一个 Windows 包在不可见的隔离桌面完成 1280×720 和 1024×768 回放，另通过双结局、续营、战败恢复、0.1.0 与上一版试玩包的旧档接续。首次独立试玩和完整人工长线试玩待验收。 [发行验证](../build/polish-bow-aim/windows-release-check.log) · [Windows 试玩包](../build/polish-bow-aim/Fiefdom-bow-aim-preview-Windows-x64.zip)

## 从轮作簿委派菽与下茬

- 上一版 Windows 包开启夜间备粮后，传统路线的自动回放仍在公田手播 45 次、换种 37 次。旧版签过轮作簿的双井田档也只能续播固定种子。 [旧版通关统计](../build/polish-field-rotation-plans/previous-windows-campaign.log) · [旧版续播对照](../build/polish-field-rotation-plans/previous-windows-replay.log)
- 和渠伯签簿后，可从田南轮作簿打开「封地概览」，选作物后勾选「与菽轮作」。计划可落到一格，也可批量安排当前井田的私田。门客在未留肥的空畦先播菽，肥地接种另一茬，稻需要等渠水。田格显示下茬。固定续播和取消安排沿用现有入口。 [轮作簿](../build/polish-field-rotation-plans/final-frames/1280x720/01-rotation-book.png) · [封地概览](../build/polish-field-rotation-plans/final-frames/1280x720/02-first-field-plans.png)
- 专项预置第 32 天的两块井田、已翻地和待记簿的进度，并延后敌袭。玩家实际找渠伯签簿，安排三格，正常过夜五次，消耗 15 份口粮。公田新增 3 份纳贡，私仓得到 2 份稻和 2 份麦，未手动播种、浇水或收割。稻等渠水的阶段经过存读档，接通水渠后在西市期间播下。上一版实际保存的两条固定计划照旧读取，原档和验证副本的校验值一致。 [窄窗口待渠水](../build/polish-field-rotation-plans/final-frames/1024x768/03-rice-waits-for-water.png) · [旧档接续](../build/polish-field-rotation-plans/legacy-field-rotation-plans.log)
- Godot 导入、脚本加载、启动及 24 项回归通过。最终 Windows 包在不可见隔离桌面完成 1280×720 和 1024×768 回放，并另行通过新档双结局、续营、战败恢复、研究与旧档接续。使用轮作委派的完整人工长线试玩待验收。 [Godot 回归](../build/polish-field-rotation-plans/godot-field-rotation-plans.log) · [发行验证](../build/polish-field-rotation-plans/windows-release-check.log) · [Windows 试玩包](../build/polish-field-rotation-plans/Fiefdom-field-rotation-plans-preview-Windows-x64.zip)

## 蒲宁等手记时的邻里日程

- 上一版 Windows 包里，手记齐了之后，第 33 天和第 34 天都只有蒲宁，邻里手记也算不出陶辛的下次来访。现在蒲宁在竹径等候，其他来客照常赴约。历书同时写出当日轮访与交接，舆图能标出两人的实际位置。 [旧版回放](../build/polish-neighbor-handoff/previous-windows-replay.log) · [历书](../build/polish-neighbor-handoff/final-frames/1024x768/01-almanac.png) · [人物舆图](../build/polish-neighbor-handoff/final-frames/1280x720/02-people-map.png)
- 专项从预置的第 33 天开始，已有三页水迹和交样绸的记录，延后了敌袭。正常过夜到第 34 天，再调到白日时辰沿西路进市，看到陶辛照常在绸摊。回封地按指路找到蒲宁并交手记，他走去药圃。当天存读档恢复两人的去处，招募蒲宁后陶辛仍在酉时回到南路亭。同日仍只能招募一人。 [陶辛下次来访](../build/polish-neighbor-handoff/final-frames/1280x720/03-next-visit.png) · [西市见面](../build/polish-neighbor-handoff/final-frames/1024x768/04-market-visit.png) · [竹径交接](../build/polish-neighbor-handoff/final-frames/1024x768/05-handoff.png)
- 旧版程序写出的待交手记存档保留三页水迹，继续后恢复了陶辛的西市行程。另一段回放验证轮访歇日蒲宁仍在竹径，轮到他来访时只出现一位蒲宁，勘渠和守备复盘也可照常接续。27 项 Godot 回归通过。最终 Windows 包在不可见隔离桌面核对两种窗口，另通过新档双结局、续营、战败恢复和旧档。独立首次试玩与人工长线验收待完成。 [旧档接续](../build/polish-neighbor-handoff/legacy-neighbor-handoff.log) · [Godot 回归](../build/polish-neighbor-handoff/godot-neighbor-handoff.log) · [发行验证](../build/polish-neighbor-handoff/windows-release-check.log) · [Windows 试玩包](../build/polish-neighbor-handoff/Fiefdom-neighbor-handoff-preview-Windows-x64.zip)

## 雨天过关与室内外环境声

- 封地、竹涧和西市共享雨声播放进度。进堂屋时雨声渐轻，高频减弱，出门恢复。竹涧的溪声和林鸟随距离淡出。西市沿用封地和竹涧的季节规则，晴天夏秋入夜才有虫鸣。
- 专项预置谷雨第 6 天和白日时辰，回放实际走过东关、西关和堂屋门口。旧包录音中，切图时雨声比过关前低至少 15 dB 的连续时段在东关约 175 毫秒，西关约 250 毫秒。新版在两条关道接续播放。新版堂屋内的雨声录音比室外约轻 17 dB。回标题和正常过夜至晴天时雨声淡出。另在西市同一处分别设置夏夜和冬夜核对虫鸣。 [旧版东关录音](../build/polish-ambience-travel/baseline-frames/1280x720/01-east-gate.wav) · [新版东关录音](../build/polish-ambience-travel/final-frames/1280x720/01-east-gate.wav) · [堂屋内录音](../build/polish-ambience-travel/final-frames/1280x720/04-rain-indoors.wav)
- Godot 导入、脚本加载、标题启动及 26 项回归通过。同一个 Windows 包在不可见的隔离桌面录制 1280×720 和 1024×768 窗口下的环境音，两次录音均消除了过关时的明显降音。发行验证通过新档双结局、续营、战败恢复、研究期限和两份旧档接续。首次独立试玩与完整人工长线试玩待验收。 [Godot 回归](../build/polish-ambience-travel/godot-ambience-travel.log) · [窄窗口回放](../build/polish-ambience-travel/final-frames/1024x768/render.log) · [发行验证](../build/polish-ambience-travel/windows-release-check.log) · [Windows 试玩包](../build/polish-ambience-travel/Fiefdom-ambience-travel-preview-Windows-x64.zip)

## 从封地指路到西市摊位

- 上一版从溪鱼簿选「去西市交鱼」时，封地标出西关，进市后指引结束。现在过关后继续标到鱼摊前，买粮和已备齐的时令单也能指到相应摊位或收货牌。西市舆图按实际石板路、摊位和角色坐标绘制，可改选三个摊位、收货牌或回封地。关闭地图后可看方向箭头和地上金色标记。 [旧版进西市](../build/polish-market-wayfinding/baseline-frames/1280x720/02-old-market-arrival.png) · [过关后指向鱼摊](../build/polish-market-wayfinding/final-frames/1280x720/02-market-arrival.png) · [窄窗口舆图](../build/polish-market-wayfinding/final-frames/1024x768/03-market-chart.png)
- 专项预置第 35 天、已认识蒲宁、私仓有两份稻和两尾白鲦。从溪鱼簿出发，分别在封地和西市保存后继续，仍能找到鱼摊。实际走到摊前交一尾白鲦，收到 13 铜钱，再选收货牌和返程关口。上一版程序在西市写出的存档可接续，保留两尾白鲦并从无指引状态进入，原档和验证副本的校验值一致。 [旧市集档接续](../build/polish-market-wayfinding/legacy-market-save.log)
- Godot 导入、脚本加载、标题启动和 21 项回归通过。最终 Windows 包在不可见的隔离桌面复核 1280×720 和 1024×768 窗口，使用模拟手柄的 Y、摇杆、A、X、B 选中收货牌并打开、关闭交货簿。发行验证通过新档双结局、续营、战败恢复、研究期限和旧档接续。首次独立试玩、实体手柄和完整人工长线试玩待验收。 [手柄收货簿](../build/polish-market-wayfinding/final-frames/1024x768/05-delivery-board.png) · [Godot 回归](../build/polish-market-wayfinding/godot-market-wayfinding-verified.log) · [发行验证](../build/polish-market-wayfinding/windows-release-check.log) · [Windows 试玩包](../build/polish-market-wayfinding/Fiefdom-market-wayfinding-preview-Windows-x64.zip)

## 从西市找到返程的陶辛

- 上一版邻里手记把玩家指到西关，进西市后即使陶辛已经到场也没有指引。申时他返程时，封地仍指向西关。现在提前到西市会指向午时约见的绸摊，陶辛到场后，标记随他移动，舆图显示他的头像。等他离开西市，指引先带玩家回封地，再指向酉时的南路亭。 [上一版西市](../build/polish-merchant-itinerary/baseline-frames/1280x720/02-old-market-no-guide.png) · [上一版返程](../build/polish-merchant-itinerary/baseline-frames/1280x720/04-old-return-gate.png) · [新版西市舆图](../build/polish-merchant-itinerary/final-frames/1280x720/02a-merchant-on-market-chart.png) · [新版返程](../build/polish-merchant-itinerary/final-frames/1024x768/04b-estate-pavilion-guide.png)
- 专项从新档耕作，预置一匹绸并推迟敌袭。第 4 天在西廊交样，第 9 天沿实际关道往返。在时辰转换前设置时钟，回放午时到市、申时返程和酉时抵亭。封地和西市两次存读档都保留指引，交谈后结束。雨天可从封地找到陶辛，招募后由门客岗位接续。上一版写出的西市存档保留来客和样绸，可选择新指引，原档和验证副本的校验值一致。 [旧市集档接续](../build/polish-merchant-itinerary/legacy-market-save.log)
- Godot 导入、脚本加载、标题启动和 23 项回归通过。同一个 Windows 包在不可见的隔离桌面完成 1280×720 和 1024×768 回放，返程文字在人物栏完整显示。发行验证另通过新档双结局、续营、战败恢复、研究期限和两份旧档接续。首次独立试玩和完整人工长线试玩待验收。 [Godot 回归](../build/polish-merchant-itinerary/godot-merchant-itinerary.log) · [发行验证](../build/polish-merchant-itinerary/windows-release-check.log) · [Windows 试玩包](../build/polish-merchant-itinerary/Fiefdom-merchant-itinerary-preview-Windows-x64.zip)

## 缺粮夜的门客分餐

- 上一版在第 49 天的同一预置档中用掉两份粮，三名门客都掉忠诚，季青和石墨一起离任。现在按留任顺序分整份口粮，可指定一名门客优先。睡前可看谁会领足、缺餐或离任，也能直接打开门客分工。剩下的零散口粮留在粮仓，晨间回执记下实耗和人名。 [旧版缺粮回执](../build/polish-ration-priority/baseline-frames/1280x720/03-old-shortage-receipt.png) · [默认分餐](../build/polish-ration-priority/final-frames/1280x720/01-default-forecast.png)
- 专项预置三名门客、粮仓两份、夜需五份，开启夜间缫丝并留三只茧。用同一份睡前档操作下拉菜单和过夜按钮。季青优先时增加 5 点礼经验，石墨离任。石墨优先时产出 3 份生丝，季青离任。两次都实耗两份粮，公仓和铜钱没有变动。睡前存档保留优先人选，晨间续档恢复离任记录。上一版实际写出的第 50 天存档保留实耗两份的回执，原档和验证副本校验值一致。 [季青优先](../build/polish-ration-priority/final-frames/1024x768/02-teacher-first.png) · [晨间回执](../build/polish-ration-priority/final-frames/1024x768/04-morning-receipt.png) · [旧档接续](../build/polish-ration-priority/legacy-ration-save.log)
- Godot 导入、脚本加载、标题启动和 23 项回归通过。最终 Windows 包在不可见的隔离桌面复核 1280×720 和 1024×768 窗口，并通过新档双结局、续营、战败恢复、研究期限和两份旧档接续。首次独立试玩和完整人工长线试玩待验收。 [Godot 回归](../build/polish-ration-priority/godot-ration-priority.log) · [发行验证](../build/polish-ration-priority/windows-release-check.log) · [Windows 试玩包](../build/polish-ration-priority/Fiefdom-ration-priority-preview-Windows-x64.zip)
