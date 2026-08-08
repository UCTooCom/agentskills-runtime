
# HLT（测试级别用例）运行说明

## HLT文件所在位置

test/HLT下log_test_xx.cj的仓颉文件
```shell
├── doc
├── src
├── test
│   ├── HLT
│   │    ├── src
│   │    │    ├── resources
│   │    │       ├── logcj.json
│   │    ├── log_test_xx.cj
│   │    ├── ...
```

## HLT运行先决条件

### 新建文件夹cjtest（和项目位于一个机器）

### 下载[测试库](https://gitee.com/HW-PLLab/cj_test)，将测试库中src目录下cjtest和conf.cfg 文件复制到cjtest中

### 打开conf.cfg，配置3rd_party_root，具体值为项目路径的上一层，例如项目路径为xxx/workspace/log-cj，则配置为xxx/workspace

### 配置环境变量，export PATH=$PATH:xxx/cjtest/:cjtest


## 运行HLT

### 进入项目HLT文件所在目录

```cangjie
cd log-cj/test/
```

### 运行HLT全部用例

```cangjie
cjtest HLT/
```
**出现`Ratio  : 100.0%`字眼，则表示运行成功**


### 运行单个用例文件

```cangjie
cjtest HLT/log_test_xx.cj
```
**出现`Ratio  : 100.0%`字眼，则表示运行成功**

### 运行HLT全部用例结果样例

```cangjie
helongfei@test-zhangxiaoyang:~/workspace/log-cj/test$ cjtest HLT/
line://3rd_party_lib:log-cj/build/logcj
[2023-08-01 15:51:33,065] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/logcj']
line://3rd_party_lib:log-cj/build/zip4cj
[2023-08-01 15:51:33,066] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/zip4cj']
line://3rd_party_lib:log-cj/build/charset
[2023-08-01 15:51:33,066] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/charset']
[2023-08-01 15:51:33,066] [INFO] ************************Start to run case file: HLT/log_test_01.cj************************
[2023-08-01 15:51:33,066] [INFO] [Run CMD]cjc -O2   --import-path /home/helongfei/workspace/log-cj/build/logcj/.. -L /home/helongfei/workspace/log-cj/build/logcj -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils  --import-path /home/helongfei/workspace/log-cj/build/zip4cj/.. -L /home/helongfei/workspace/log-cj/build/zip4cj -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils  --import-path /home/helongfei/workspace/log-cj/build/charset/.. -L /home/helongfei/workspace/log-cj/build/charset -l charset_charset.simplechinese -l charset_charset.korean -l charset_charset.japanese -l charset_charset.unicode -l charset_charset -l charset_charset.encoding -l charset_charset.singlebyte -l charset_charset.traditionchinese   HLT/log_test_01.cj  -o tmp/HLT/log_test_01.cj.out --test
[2023-08-01 15:51:35,222] [INFO] [Run CMD]cd tmp/HLT;./log_test_01.cj.out  
[2023-08-01 15:51:35,239] [INFO] enter default...
[2023-08-01 15:51:35,240] [INFO] 
[2023-08-01 15:51:35,240] [INFO] [2023/08/01 15:51:35 CST 231] [ALL] [logRecord_02] (source) message
[2023-08-01 15:51:35,240] [INFO] 
[2023-08-01 15:51:35,240] [INFO] 
[2023-08-01 15:51:35,240] [INFO] 2023/08/01 15:51:35 CST 231 ALL logRecord_02 source message
[2023-08-01 15:51:35,240] [INFO] 
[2023-08-01 15:51:35,240] [INFO] +++++2023/08/01 15:51:35 CST55 231+-- ##ALL#$ logRecord_02 (source) message
[2023-08-01 15:51:35,240] [INFO] 
[2023-08-01 15:51:35,240] [INFO] [2023/08/01 15:51:35 CST 231] [TRACE] [] ()
[2023-08-01 15:51:35,240] [INFO] 
[2023-08-01 15:51:35,240] [INFO] [2023/08/01 15:51:35 CST 231] [DEBUG] [@#$^,;[^&^%**(] (_+(^^&/\@$@&) %^&*' '&(*@#
[2023-08-01 15:51:35,240] [INFO] 
[2023-08-01 15:51:35,241] [INFO] --------------------------------------------------------------------------------------------------
[2023-08-01 15:51:35,241] [INFO] TP: test, time elapsed: 292910 ns, Result:
[2023-08-01 15:51:35,241] [INFO] TCS: LogTestA, time elapsed: 291118 ns, RESULT:
[2023-08-01 15:51:35,241] [INFO] [ PASSED ] CASE: log_test_001 (25288 ns)
[2023-08-01 15:51:35,241] [INFO] [ PASSED ] CASE: log_test_002 (10442 ns)
[2023-08-01 15:51:35,241] [INFO] [ PASSED ] CASE: log_test_003 (171005 ns)
[2023-08-01 15:51:35,241] [INFO] [ PASSED ] CASE: log_test_004 (8644 ns)
[2023-08-01 15:51:35,241] [INFO] [ PASSED ] CASE: log_test_005 (14028 ns)
[2023-08-01 15:51:35,241] [INFO] [ PASSED ] CASE: log_test_006 (33814 ns)
[2023-08-01 15:51:35,241] [INFO] [ PASSED ] CASE: log_test_007 (18080 ns)
[2023-08-01 15:51:35,241] [INFO] Summary: TOTAL: 7
[2023-08-01 15:51:35,241] [INFO] PASSED: 7, SKIPPED: 0, ERROR: 0
[2023-08-01 15:51:35,241] [INFO] FAILED: 0
[2023-08-01 15:51:35,241] [INFO] --------------------------------------------------------------------------------------------------
line://3rd_party_lib:log-cj/build/logcj
[2023-08-01 15:51:35,242] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/logcj']
line://3rd_party_lib:log-cj/build/zip4cj
[2023-08-01 15:51:35,242] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/zip4cj']
line://3rd_party_lib:log-cj/build/charset
[2023-08-01 15:51:35,243] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/charset']
[2023-08-01 15:51:35,243] [INFO] ************************Start to run case file: HLT/log_test_05.cj************************
[2023-08-01 15:51:35,243] [INFO] Start to copy data files
[2023-08-01 15:51:35,243] [INFO] copy HLT/src/resources/logcj.json to tmp/HLT/src/resources/logcj.json
[2023-08-01 15:51:35,243] [INFO] [Run CMD]cjc -O2   --import-path /home/helongfei/workspace/log-cj/build/logcj/.. -L /home/helongfei/workspace/log-cj/build/logcj -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils  --import-path /home/helongfei/workspace/log-cj/build/zip4cj/.. -L /home/helongfei/workspace/log-cj/build/zip4cj -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils  --import-path /home/helongfei/workspace/log-cj/build/charset/.. -L /home/helongfei/workspace/log-cj/build/charset -l charset_charset.simplechinese -l charset_charset.korean -l charset_charset.japanese -l charset_charset.unicode -l charset_charset -l charset_charset.encoding -l charset_charset.singlebyte -l charset_charset.traditionchinese   HLT/log_test_05.cj  -o tmp/HLT/log_test_05.cj.out --test
[2023-08-01 15:51:44,979] [INFO] [Run CMD]cd tmp/HLT;./log_test_05.cj.out  
[2023-08-01 15:51:44,995] [INFO] [15:51:44 CST 2023/08/01] [ALL] (source) [message]
[2023-08-01 15:51:44,995] [INFO] [15:51:44 CST 2023/08/01] [ALL] (source) [message]
[2023-08-01 15:51:44,995] [INFO] enter default...
[2023-08-01 15:51:44,996] [INFO] enter default...
[2023-08-01 15:51:44,996] [INFO] --------------------------------------------------------------------------------------------------
[2023-08-01 15:51:44,996] [INFO] TP: test, time elapsed: 1122577 ns, Result:
[2023-08-01 15:51:44,996] [INFO] TCS: LogTestE, time elapsed: 1120347 ns, RESULT:
[2023-08-01 15:51:44,996] [INFO] [ PASSED ] CASE: log_test_050 (153721 ns)
[2023-08-01 15:51:44,996] [INFO] [ PASSED ] CASE: log_test_051 (73768 ns)
[2023-08-01 15:51:44,996] [INFO] [ PASSED ] CASE: log_test_052 (194760 ns)
[2023-08-01 15:51:44,996] [INFO] [ PASSED ] CASE: log_test_053 (144984 ns)
[2023-08-01 15:51:44,996] [INFO] [ PASSED ] CASE: log_test_054 (211396 ns)
[2023-08-01 15:51:44,996] [INFO] [ PASSED ] CASE: log_test_055 (333854 ns)
[2023-08-01 15:51:44,996] [INFO] Summary: TOTAL: 6
[2023-08-01 15:51:44,996] [INFO] PASSED: 6, SKIPPED: 0, ERROR: 0
[2023-08-01 15:51:44,996] [INFO] FAILED: 0
[2023-08-01 15:51:44,996] [INFO] --------------------------------------------------------------------------------------------------
line://3rd_party_lib:log-cj/build/logcj
[2023-08-01 15:51:44,997] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/logcj']
line://3rd_party_lib:log-cj/build/zip4cj
[2023-08-01 15:51:44,997] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/zip4cj']
line://3rd_party_lib:log-cj/build/charset
[2023-08-01 15:51:44,997] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/charset']
[2023-08-01 15:51:44,998] [INFO] ************************Start to run case file: HLT/log_test_03.cj************************
[2023-08-01 15:51:44,998] [INFO] [Run CMD]cjc -O2   --import-path /home/helongfei/workspace/log-cj/build/logcj/.. -L /home/helongfei/workspace/log-cj/build/logcj -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils  --import-path /home/helongfei/workspace/log-cj/build/zip4cj/.. -L /home/helongfei/workspace/log-cj/build/zip4cj -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils  --import-path /home/helongfei/workspace/log-cj/build/charset/.. -L /home/helongfei/workspace/log-cj/build/charset -l charset_charset.simplechinese -l charset_charset.korean -l charset_charset.japanese -l charset_charset.unicode -l charset_charset -l charset_charset.encoding -l charset_charset.singlebyte -l charset_charset.traditionchinese   HLT/log_test_03.cj  -o tmp/HLT/log_test_03.cj.out --test
[2023-08-01 15:51:55,487] [INFO] [Run CMD]cd tmp/HLT;./log_test_03.cj.out  
[2023-08-01 15:51:55,503] [INFO] --------------------------------------------------------------------------------------------------
[2023-08-01 15:51:55,503] [INFO] TP: test, time elapsed: 81103 ns, Result:
[2023-08-01 15:51:55,504] [INFO] TCS: LogTestC, time elapsed: 79423 ns, RESULT:
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_025 (9530 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_026 (2523 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_027 (2087 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_028 (1852 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_029 (2052 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_030 (4076 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_031 (1961 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_032 (2972 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_033 (13105 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_034 (2774 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_035 (3669 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_036 (2089 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_037 (1901 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_038 (1533 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_039 (9938 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_040 (1542 ns)
[2023-08-01 15:51:55,504] [INFO] [ PASSED ] CASE: log_test_041 (2113 ns)
[2023-08-01 15:51:55,505] [INFO] Summary: TOTAL: 17
[2023-08-01 15:51:55,505] [INFO] PASSED: 17, SKIPPED: 0, ERROR: 0
[2023-08-01 15:51:55,505] [INFO] FAILED: 0
[2023-08-01 15:51:55,505] [INFO] --------------------------------------------------------------------------------------------------
line://3rd_party_lib:log-cj/build/logcj
[2023-08-01 15:51:55,505] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/logcj']
line://3rd_party_lib:log-cj/build/zip4cj
[2023-08-01 15:51:55,506] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/zip4cj']
line://3rd_party_lib:log-cj/build/charset
[2023-08-01 15:51:55,506] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/charset']
[2023-08-01 15:51:55,506] [INFO] ************************Start to run case file: HLT/log_test_04.cj************************
[2023-08-01 15:51:55,506] [INFO] [Run CMD]cjc -O2   --import-path /home/helongfei/workspace/log-cj/build/logcj/.. -L /home/helongfei/workspace/log-cj/build/logcj -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils  --import-path /home/helongfei/workspace/log-cj/build/zip4cj/.. -L /home/helongfei/workspace/log-cj/build/zip4cj -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils  --import-path /home/helongfei/workspace/log-cj/build/charset/.. -L /home/helongfei/workspace/log-cj/build/charset -l charset_charset.simplechinese -l charset_charset.korean -l charset_charset.japanese -l charset_charset.unicode -l charset_charset -l charset_charset.encoding -l charset_charset.singlebyte -l charset_charset.traditionchinese   HLT/log_test_04.cj  -o tmp/HLT/log_test_04.cj.out --test
[2023-08-01 15:52:03,200] [INFO] [Run CMD]cd tmp/HLT;./log_test_04.cj.out  
[2023-08-01 15:52:27,389] [INFO] true
[2023-08-01 15:52:27,389] [INFO] true
[2023-08-01 15:52:27,390] [INFO] true
[2023-08-01 15:52:27,390] [INFO] true
[2023-08-01 15:52:27,390] [INFO] true
[2023-08-01 15:52:27,390] [INFO] [15:52:27 CST 2023/08/01 378] [ALL][logRecord_01] (source) message
[2023-08-01 15:52:27,390] [INFO] [15:52:27 CST 2023/08/01 378] [ALL][logRecord_01] (source) message
[2023-08-01 15:52:27,390] [INFO] [15:52:27 CST 2023/08/01] [ALL] (source) [message]
[2023-08-01 15:52:27,390] [INFO] [15:52:27 CST 2023/08/01] [ALL] (source) [message]
[2023-08-01 15:52:27,390] [INFO] --------------------------------------------------------------------------------------------------
[2023-08-01 15:52:27,390] [INFO] TP: test, time elapsed: 24170509095 ns, Result:
[2023-08-01 15:52:27,390] [INFO] TCS: LogTestD, time elapsed: 24170506562 ns, RESULT:
[2023-08-01 15:52:27,390] [INFO] [ PASSED ] CASE: log_test_042 (15685 ns)
[2023-08-01 15:52:27,390] [INFO] [ PASSED ] CASE: log_test_043 (60434 ns)
[2023-08-01 15:52:27,390] [INFO] [ PASSED ] CASE: log_test_044 (44461 ns)
[2023-08-01 15:52:27,390] [INFO] [ PASSED ] CASE: log_test_045 (2038 ns)
[2023-08-01 15:52:27,390] [INFO] [ PASSED ] CASE: log_test_046 (3111575967 ns)
[2023-08-01 15:52:27,390] [INFO] [ PASSED ] CASE: log_test_047 (15026389126 ns)
[2023-08-01 15:52:27,390] [INFO] [ PASSED ] CASE: log_test_048 (6032200351 ns)
[2023-08-01 15:52:27,390] [INFO] [ PASSED ] CASE: log_test_049 (151794 ns)
[2023-08-01 15:52:27,391] [INFO] [ PASSED ] CASE: log_test_050 (34414 ns)
[2023-08-01 15:52:27,391] [INFO] Summary: TOTAL: 9
[2023-08-01 15:52:27,391] [INFO] PASSED: 9, SKIPPED: 0, ERROR: 0
[2023-08-01 15:52:27,391] [INFO] FAILED: 0
[2023-08-01 15:52:27,391] [INFO] --------------------------------------------------------------------------------------------------
line://3rd_party_lib:log-cj/build/logcj
[2023-08-01 15:52:27,391] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/logcj']
line://3rd_party_lib:log-cj/build/zip4cj
[2023-08-01 15:52:27,392] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/zip4cj']
line://3rd_party_lib:log-cj/build/charset
[2023-08-01 15:52:27,392] [INFO] find 3rd party libs in ['/home/helongfei/workspace/log-cj/build/charset']
[2023-08-01 15:52:27,392] [INFO] ************************Start to run case file: HLT/log_test_02.cj************************
[2023-08-01 15:52:27,392] [INFO] [Run CMD]cjc -O2   --import-path /home/helongfei/workspace/log-cj/build/logcj/.. -L /home/helongfei/workspace/log-cj/build/logcj -l logcj_appender -l logcj_config -l logcj_logger -l logcj_utils  --import-path /home/helongfei/workspace/log-cj/build/zip4cj/.. -L /home/helongfei/workspace/log-cj/build/zip4cj -l zip4cj_zip4cj.zip -l zip4cj_zip4cj.utils  --import-path /home/helongfei/workspace/log-cj/build/charset/.. -L /home/helongfei/workspace/log-cj/build/charset -l charset_charset.simplechinese -l charset_charset.korean -l charset_charset.japanese -l charset_charset.unicode -l charset_charset -l charset_charset.encoding -l charset_charset.singlebyte -l charset_charset.traditionchinese   HLT/log_test_02.cj  -o tmp/HLT/log_test_02.cj.out --test
[2023-08-01 15:52:31,502] [INFO] [Run CMD]cd tmp/HLT;./log_test_02.cj.out  
[2023-08-01 15:52:31,518] [INFO] --------------------------------------------------------------------------------------------------
[2023-08-01 15:52:31,518] [INFO] TP: test, time elapsed: 62349 ns, Result:
[2023-08-01 15:52:31,518] [INFO] TCS: LogTestB, time elapsed: 60935 ns, RESULT:
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_008 (13735 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_009 (5372 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_010 (2846 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_011 (2884 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_012 (3098 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_013 (2704 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_014 (1269 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_015 (3115 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_016 (1181 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_017 (1326 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_018 (1219 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_019 (1609 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_020 (770 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_021 (811 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_022 (893 ns)
[2023-08-01 15:52:31,519] [INFO] [ PASSED ] CASE: log_test_023 (804 ns)
[2023-08-01 15:52:31,520] [INFO] [ PASSED ] CASE: log_test_024 (1102 ns)
[2023-08-01 15:52:31,520] [INFO] Summary: TOTAL: 17
[2023-08-01 15:52:31,520] [INFO] PASSED: 17, SKIPPED: 0, ERROR: 0
[2023-08-01 15:52:31,520] [INFO] FAILED: 0
[2023-08-01 15:52:31,520] [INFO] --------------------------------------------------------------------------------------------------
[2023-08-01 15:52:31,527] [INFO] **************************************************
[2023-08-01 15:52:31,527] [INFO] Test Summary
[2023-08-01 15:52:31,527] [INFO] Total  : 56
[2023-08-01 15:52:31,527] [INFO] Passed : 56
[2023-08-01 15:52:31,527] [INFO] Failed : 0
[2023-08-01 15:52:31,527] [INFO] Error  : 0
[2023-08-01 15:52:31,528] [INFO] Skipped: 0
[2023-08-01 15:52:31,528] [INFO] Ratio  : 100.0%
[2023-08-01 15:52:31,528] [INFO] **************************************************
[2023-08-01 15:52:31,528] [INFO] View the full log in log/all.log, or view the log of each case under log/split_log
```