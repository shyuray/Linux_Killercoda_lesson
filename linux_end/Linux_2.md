# Stage 2｜服務在跑，但只有自己連得到
<br>

## 這一關的處境
<br>

公司還有一套報表 API，跑在 port 8080。同事說連不到。

你查狀態，它是 `active (running)`。你在機器上 `curl localhost:8080`，正常回應。

設定沒錯、權限沒錯、磁碟沒滿、服務活著、你自己測也通。

**但同事就是連不到。**

---
<br>

## 你今天只需要知道這些
<br>

前面說「程式向核心註冊 port」，那句話少講了一半。

**程式註冊的其實是「IP + port」這一組，不是只有 port。** 因為一台機器有好幾個 IP。

你的機器至少有兩個：

```text
127.0.0.1    lo 介面（loopback）
10.0.2.15    真實的網路介面
```

`lo` 是 loopback，一個虛擬介面，不對應任何實體網卡。送到 `127.0.0.1` 的資料，核心直接送回本機的程式，**資料不會經過網卡、不會離開這台機器**。它存在的目的，就是讓同一台機器上的程式互相溝通。

所以一個程式可以選擇註冊：

| 註冊什麼 | 結果 |
| :--- | :--- |
| `127.0.0.1:8080` | 只有從 loopback 進來的資料會交給它。loopback 的資料只可能來自本機，**外部永遠送不到** |
| `10.0.2.15:8080` | 只有送到這個 IP 的資料會交給它 |
| `0.0.0.0:8080` | `0.0.0.0` 是特殊值，意思是「這台機器上**所有** IP」。送到哪個 IP 都交給它 |

**這就是「本機測都正常，但別人連不到」的機制。**

不是服務有問題、不是防火牆擋、不是網路斷。是那個程式從一開始就只註冊了 loopback。**外部的資料根本沒有對應的紀錄可以查，核心直接拒絕。**

---
<br>

## 角色 / 工具速查表
<br>

| 你想知道 | 打這個 |
| :--- | :--- |
| 這個服務註冊在哪個位址？ | `sudo ss -tlnp sport = :8080` |
| 這台機器的 IP 是多少？ | `ip a` |
| 從本機連 | `curl localhost:8080` |
| 用真實 IP 連（等於從網路上連） | `curl <IP>:8080` |
| 這個服務是怎麼被啟動的？ | `systemctl cat report-api` |

---
<br>

## 跟著做
<br>

**第一步：確認它真的在跑。**

`systemctl status report-api --no-pager`{{execute}}

*→ active (running)。服務本身沒問題。*

**第二步：從本機連。**

`curl localhost:8080`{{execute}}

*→ 通。所以服務確實有在回應。*

**第三步：找出這台機器的真實 IP。**

`ip a`{{execute}}

*→ 只看 `inet` 開頭的行。`127.0.0.1` 是 lo，那是 loopback，永遠指向自己。另一個（`10.x.x.x`）才是這台機器在網路上的位址。*

**第四步：用真實 IP 連。這一步跟第二步驗的不是同一件事。**

`curl $(hostname -I | awk '{print $1}'):8080`{{execute}}

*→ `hostname -I` 印出這台機器的 IP，`awk '{print $1}'` 取第一個。*
*→ 連不上。**同一個服務，localhost 通、真實 IP 不通。***

**第五步：去問核心，它到底註冊在哪個位址。**

`sudo ss -tlnp sport = :8080`{{execute}}

*→ 答案就在 Local Address 那一欄。*

**第六步：對照 nginx 的，看正常的長什麼樣。**

`sudo ss -tlnp sport = :80`{{execute}}

*→ 兩個服務，左邊那一欄不一樣。*

---
<br>

## 看懂結果
<br>

```text
LISTEN  0  5    127.0.0.1:8080  ...  users:(("python3",...))   ← 報表 API
LISTEN  0  511    0.0.0.0:80    ...  users:(("nginx",...))     ← nginx
```

| 你看到 | 意思 | 外部連得到嗎 |
| :--- | :--- | :--- |
| `0.0.0.0:80` | 所有 IP 都收 | 連得到 |
| `127.0.0.1:8080` | 只收 loopback | **永遠連不到** |
| `[::]:80` | IPv6 版的 `0.0.0.0` | 連得到（走 IPv6） |

**`curl localhost` 通不通，不能證明外部連得到。** 這兩個指令走的路不同：localhost 走 loopback，永遠不出機器；真實 IP 走網路介面。

---
<br>

## 修好它
<br>

問題在服務啟動時帶的參數。看它是怎麼被啟動的：

`systemctl cat report-api`{{execute}}

*→ 看 `ExecStart` 那一行，結尾是 `--bind 127.0.0.1`。*

改掉它：

`nano /etc/systemd/system/report-api.service`{{execute}}

*→ 把 `--bind 127.0.0.1` 改成 `--bind 0.0.0.0`。Ctrl+O 存檔、Enter 確認、Ctrl+X 離開。*

**改完 systemd 不知道你改了。** 這一步上一階段學過：

`systemctl daemon-reload`{{execute}}

`systemctl restart report-api`{{execute}}

驗證：

`sudo ss -tlnp sport = :8080`{{execute}}

`curl $(hostname -I | awk '{print $1}'):8080`{{execute}}

*→ 位址變成 `0.0.0.0:8080`，用真實 IP 也連得到了。*

---
<br>

## 常見誤會
<br>

**「我在機器上測都好好的，一定是同事那邊的網路問題。」**

這句話是這一關的全部。你測的是 loopback，他走的是網路，兩條路不同。**在本機測通，不能證明外部連得到。**

**「服務 active，那服務就沒問題。」**

`active` 只代表那個程式在執行。它註冊在哪個位址、有沒有真的能被外部連到，`systemctl status` 一個字都不會提。

**「改了設定檔，restart 就會生效。」**

改的是**服務自己的設定檔**（像 nginx.conf），restart 就夠。改的是 **systemd 的 unit 檔**（`/etc/systemd/system/*.service`），要先 `daemon-reload`，因為 systemd 把 unit 檔的內容記在記憶體裡。

---
<br>

## 觀念確認（小任務）
<br>

一個服務 `systemctl status` 顯示 active，`curl localhost:8080` 正常回應，但同事連不到。你會先查什麼？

- A. 防火牆
- B. `sudo ss -tlnp`，看它註冊在哪個位址
- C. 重啟服務

**建議答案是 B。** 防火牆確實有可能，但監聽位址是更前面的一層——**如果它只註冊了 127.0.0.1，資料根本到不了防火牆那一關就被核心拒絕了。** 先查前面的，再查後面的。

---

> ### 分診進度
>
> 服務在跑、監聽 `0.0.0.0`、你自己用真實 IP 也連得到。
>
> 但如果這兩層都對，外部還是連不到呢？
>
> **下一關：防火牆。**
