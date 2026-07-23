# 第 5 章｜系統打不開了
<br>

## 為什麼要學這個
<br>

業務部說訂單查詢系統打不開。你連上伺服器，指令都有回應，機器沒有關機。

**機器還開著，不代表它上面的每一個程式都還在執行。** 這是兩件事。

在確認服務的實際狀態之前，任何修改都只是猜測。這一章要學會的是：問出服務現在到底是哪一種狀態，然後讓它恢復。

---
<br>

## 核心觀念
<br>

一直在背景執行、隨時等著處理請求的程式，叫做**服務**。這台機器上所有服務的啟停，由 `systemd` 統一管理，你透過 `systemctl` 對它下令。

```text
【圖：你不直接碰服務，你透過 systemd】

                              ┌──▶  order-web   訂單查詢系統
                              │
   你  ──systemctl──▶  systemd ──┼──▶  ssh         遠端連線
                              │
                              └──▶  cron        排程工作
```

服務在任何時候只會是這三種狀態的其中一種：

| 狀態 | 實際發生了什麼 | 代表 |
| :--- | :--- | :--- |
| `active (running)` | 正常執行中 | 問題不在這個服務，往別處查 |
| `inactive (dead)` | 被正常關掉了，沒有出錯 | 這不是故障，直接啟動就好 |
| `failed` | 它試著啟動，中途出錯停住 | 有東西讓它跑不起來，要去讀紀錄 |

**分清楚是哪一種，決定了你接下來做什麼。** 把「被關掉」當成「啟動失敗」，你會去翻一份根本沒問題的設定檔。

---
<br>

## 這一章的指令
<br>

| 指令 | 它回答什麼 |
| :--- | :--- |
| `systemctl status 服務` | 這個服務現在是什麼狀態 |
| `systemctl start 服務` | 現在把它啟動起來 |
| `systemctl enable 服務` | 設定成開機時自動啟動 |
| `systemctl is-enabled 服務` | 開機時會不會自動啟動 |
| `curl localhost:8080` | 從外部發一個請求，看它會不會回應 |

> **`start` 和 `enable` 是兩個獨立的開關，很容易混淆。**
>
> `start` 管的是**現在**跑不跑。`enable` 管的是**下次開機**會不會自動跑。
>
> 只做 `start` 沒做 `enable`，這次救活了，機器重開之後又會不見，而且那時候通常沒有人記得這件事。

---
<br>

## 動手做
<br>

**第一步：先問狀態。**

`systemctl status order-web`{{execute}}

*→ 輸出很長。先只看第三行的 `Active:`，其餘略過。看完按 `q` 離開。*

**第二步：換個角度驗證，從外部發一個請求。**

`curl localhost:8080`{{execute}}

*→ 兩個指令從不同角度指向同一件事。*

**第三步：啟動它，然後再確認一次。**

`systemctl start order-web`{{execute}}

`systemctl status order-web`{{execute}}

`curl localhost:8080`{{execute}}

**第四步：確認開機後會不會自動啟動。**

`systemctl is-enabled order-web`{{execute}}

---
<br>

## 判讀輸出
<br>

### 1. `systemctl status` 你只要看兩行

```text
● order-web.service - Order Query System
     Loaded: loaded (/etc/systemd/system/order-web.service; disabled)
                                                             ▲
                                            開機不會自動啟動
     Active: inactive (dead) since Thu 2026-07-23 09:14:02 CST
             ▲                    ▲
        現在的狀態          從什麼時候開始
```

| 這一行 | 你要看什麼 |
| :--- | :--- |
| `Loaded:` | 括號裡的 `enabled` 或 `disabled`，代表開機會不會自動啟動 |
| `Active:` | 目前狀態，以及它從什麼時候變成這個狀態 |

**`Active:` 後面的時間很有用。** 它直接回答「從什麼時候開始壞的」，這是同事一定會問的問題。

### 2. `curl` 的兩種結果

| 你看到 | 結論 |
| :--- | :--- |
| 一段 HTML | 服務有回應，確實在提供服務 |
| `Connection refused` | 沒有任何程式在那個連接埠接收請求 |

### 3. 這些輸出代表什麼結論

| 情況 | 結論 |
| :--- | :--- |
| `Active: inactive (dead)` | 服務被關掉了，沒有出錯。直接啟動即可 |
| `Active: failed` | 它試著啟動但出錯了。**直接重啟沒有用，要先去讀紀錄找原因**（第 6 章） |
| `Active: active (running)`，但使用者仍打不開 | 服務正常，問題在別處：可能是權限、可能是連接埠 |
| `is-enabled` 回 `disabled` | 這次救活了，下次開機會再壞一次 |

> **執行 `systemctl start` 之後沒有跳出錯誤訊息，不代表服務起來了。**
>
> `systemctl` 沒報錯只代表你的指令被接受了。服務可能在背景嘗試啟動、失敗、然後放棄，而終端機這邊完全看不出來。**每一次操作之後都要用 `status` 另外確認。**

---
<br>

## 任務
<br>

| # | 找出什麼 |
| :--- | :--- |
| 1 | `order-web` 一開始的狀態是哪一種，是被關掉還是啟動失敗 |
| 2 | 把它啟動起來，並且用兩種不同的方式證明它真的在提供服務 |
| 3 | 這台機器重新開機之後，這個服務會不會自己起來 |

第 3 題如果答案是不會，想一下該用哪個指令處理。
