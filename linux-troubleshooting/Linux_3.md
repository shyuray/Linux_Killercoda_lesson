# Stage 3｜路徑一：設定錯
<br>

## 這一關的處境

`nginx -t` 已經指出來了：設定檔某一行少了一個分號。

兇手抓到了，現在要動手改。但前輩攔了你一下：

> 你等一下要改的是 **正在服務全公司的設定檔** 。改壞了，不是「再試一次」那麼簡單。
>
> 所以動手之前，先想清楚三件事：
>
> 1. 你改壞了能不能還原？
> 2. 你怎麼確定改對了？
> 3. 你重啟的時候，會不會把正在用系統的人踢下線？

---

## 你今天只需要知道這些

改設定檔有一套固定紀律，**順序不能亂**：

```text
備份 ─▶ 修改 ─▶ 驗證語法 ─▶ 套用 ─▶ 確認狀態 ─▶ 確認開機自動跑
  │       │        │          │        │            │
  防      改       防「帶著     讓新     防「以為      防「這次救活了
 改壞     它       錯誤去      設定     修好了        下次開機又不見」
 回不去            重啟」      生效     其實沒有」
```

### 一個正式環境的關鍵分辨

| 指令 | 做什麼（因） | 對使用者的影響（果） |
| :--- | :--- | :--- |
| **reload** | 讓服務重新讀一次設定檔，程序不換 | **不斷線**，使用者無感 |
| **restart** | 殺掉舊程序，起一個新的 | **服務中斷幾秒**，連線被切斷 |

> **提示：**
>
> 正式環境改設定，優先用 `reload` 。
>
> **但這次不行** —— 服務現在是 failed，已經死了，沒有東西可以 reload。
>
> 所以要用 `restart` 把它從死亡狀態拉起來。等它活著之後，以後改設定就用 `reload` 。

---
<br>

## 角色 / 工具速查表

| 你想做 | 打這個 |
| :--- | :--- |
| 備份設定檔 | `sudo cp 原檔 原檔.bak` |
| 編輯設定檔 | `sudo nano 檔案` |
| 檢查 nginx 語法 | `nginx -t` |
| 套用設定（不斷線） | `sudo systemctl reload nginx` |
| 把死掉的服務拉起來 | `sudo systemctl restart nginx` |
| 確認活了沒 | `systemctl status nginx` |
| 確認開機會自動跑 | `systemctl is-enabled nginx` |
| 從備份還原 | `sudo cp 原檔.bak 原檔` |

> **nano 求生提示：**
>
> 只要記兩個鍵：`Ctrl + O` 存檔（會問檔名，按 Enter 確認）、`Ctrl + X` 離開。
>
> 畫面最下面那排提示裡的 `^` 就是 Ctrl。

---

## 跟著做

**第一步：備份。這一步不能跳。**

`sudo cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak`{{execute}}

*→ 沒有任何輸出就是成功了。*

**第二步：改。找到剛才 `nginx -t` 指出的那一行，把漏掉的分號補上。**

`sudo nano /etc/nginx/sites-enabled/default`{{execute}}

*→ 改完按 Ctrl + O ，Enter 確認，再按 Ctrl + X 離開。*

**第三步：驗證語法。重啟之前先確認。**

`sudo nginx -t`{{execute}}

*→ 你要看到 `syntax is ok` 和 `test is successful` 。*

> **如果還是報錯，不要重啟。** 回去 nano 再改，直到這一步過關。

**第四步：套用。服務現在是死的，所以用 restart 拉起來。**

`sudo systemctl restart nginx`{{execute}}

*→ 一樣，沒有輸出。這不代表成功。*

**第五步：確認狀態。**

`systemctl status nginx`{{execute}}

*→ 你要看到 `active (running)` 。按 `q` 離開。*

`curl localhost`{{execute}}

*→ 應該吐出一堆 HTML。這才是真的證明它在服務。*

**第六步：確認開機會自動跑。**

`systemctl is-enabled nginx`{{execute}}

*→ 要看到 `enabled` 。如果是 disabled，補打一句 `sudo systemctl enable nginx` 。*

---
<br>

## 看懂結果

### 1. `nginx -t` 的兩種結果

| 你看到 | 白話翻譯 | 下一步 |
| :--- | :--- | :--- |
| **syntax is ok + test is successful** | 設定檔沒問題 | 可以安心套用重啟 |
| **[emerg] + 檔名 + 行號** | 還有錯，而且它告訴你在哪一行 | 回去改那一行，**絕對不要重啟** |

*註：錯誤訊息會直接給你檔案路徑和行號。這是設定檔類錯誤最友善的地方 —— 它不用你猜。*

### 2. 修好之後該看到什麼

| 你看到 | 代表 |
| :--- | :--- |
| **● active (running)** | 活了 |
| **Main PID: 1234 (nginx)** | 有活著的程序編號 |
| **curl 吐出 HTML** | 網站真的有回應 |
| **is-enabled 回 enabled** | 下次開機它會自己起來 |

> **觀念補充：**
>
> `restart` 之後 PID 會換一個新號碼。如果你懷疑「它到底有沒有真的重啟」，看 PID 有沒有變就知道。
>
> 這比看 `active (running)` 可靠 —— 一個沒重啟成功、還跑著舊設定的服務，狀態一樣顯示 running。

---
<br>

## 常見誤會

**「改完直接重啟，失敗再說。」**

正式環境不能這樣。帶著語法錯誤去重啟，服務會直接躺平，**而且是在你手上躺的**。先 `nginx -t` ，過了再重啟。這一步花三秒鐘，省你一場事故。

**「restart 沒報錯，所以修好了。」**

`systemctl` 只是「接受了你的指令」。服務可能在背景嘗試啟動、失敗五次之後才放棄。**任何操作後都要 `status` 確認。**

**「救活了就收工。」**

`start` 管的是**現在**跑不跑，`enable` 管的是**開機時**自動跑不跑。這是兩個獨立的開關。手動救活的服務如果從來沒 enable 過，三個月後機器重開，它再也不會起來 —— 而且那時候沒人記得這件事。

**「reload 和 restart 反正都是套用設定。」**

對線上使用者不是。restart 會中斷連線，reload 不會。**改設定優先 reload。**

---
<br>

## 觀念確認（小任務）

你在正式環境改了 nginx 的設定檔，想讓新設定生效，而且不想讓正在使用系統的同事斷線。你應該：

- A. `systemctl restart nginx`
- B. `systemctl reload nginx`
- C. 重開機

**建議答案是 B。** reload 讓服務重新讀設定檔，程序不換，使用者無感。restart 會殺掉舊程序，連線被切斷。

*（但要注意：如果服務已經是 failed 狀態，它沒在跑，沒東西可以 reload，這時就得用 restart。）*

---

> ### 分診進度：路徑一走完
>
> 服務活了、網站有回應、開機會自動跑。
>
> 但十分鐘後，同事回報：網頁打得開了，可是點進「報表下載」就跳 **403 Forbidden** 。
>
> 服務明明活著。這次不是設定的問題。
>
> **下一關：路徑二，權限。**
