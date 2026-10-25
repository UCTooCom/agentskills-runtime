-- 产业政策智能体落库 SQL
-- 生成时间: 2026-10-25T08:34:52

UPDATE public.company SET org_description = '北京中关村软件园发展有限责任公司，注册于北京市朝阳区。', region = '北京市朝阳区', org_type = 'beichen-enterprise', updated_at = CURRENT_TIMESTAMP WHERE company_name = '北京中关村软件园发展有限责任公司' AND deleted_at IS NULL;
INSERT INTO public.company (company_name, region, social_credit_code, established_time, registered_capital, registered_address, mailing_address, legal_representative, legal_representativemobile, legal_representative_email, contact_name, contact_mobile, contact_email, contact_title, website, company_introduction, business_licence, org_description, org_type) SELECT '北京中关村软件园发展有限责任公司', '北京市朝阳区', '', '', '', '', '', '', '', '', '', '', '', '', '', '北京中关村软件园发展有限责任公司，注册于北京市朝阳区。', '', '北京中关村软件园发展有限责任公司，注册于北京市朝阳区。', 'beichen-enterprise' WHERE NOT EXISTS (SELECT 1 FROM public.company WHERE company_name = '北京中关村软件园发展有限责任公司' AND deleted_at IS NULL);
-- 以下必填列未采集到，已写空串（未编造）：social_credit_code、established_time、registered_capital、registered_address、mailing_address、legal_representative、legal_representativemobile、legal_representative_email、contact_name、contact_mobile、contact_email、contact_title、website、business_licence

INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '4225ce32-a7cb-46d0-af3e-adcb8adbaf85', '政策适配报告 - 北京中关村软件园发展有限责任公司', '# 政策适配研判报告 - 北京中关村软件园发展有限责任公司

- 生成日期：2026-10-25
- 注册区域：北京市朝阳区
- 所属行业：待核实
- 企业资质：暂无

## 适用范围（务必阅读）

> 本报告的政策依据来自**本地政策原文库（北京地区政策，当前 74 条）**与公开渠道检索结果，
> **不代表全国通用**，也不覆盖各区自行发布的全部细则；跨地区或区级申报请以当地主管部门发布的原文为准。
> 未能在原文库中备案的结论，均在报告中标注「未备案」并保留可点开来源，供人工复核。

## 匹配政策清单（按匹配度排序）

| 序号 | 政策编号 | 政策名称 | 层级/领域 | 匹配度 | 匹配依据 | 来源 |
|------|---------|---------|----------|--------|---------|------|
| 1 | 1 | 北京市高层次创新创业人才支持计划科技新星计划管理办法 | 市级/人才支持 | 30 | 层级市级·领域人才支持 | — |
| 2 | 2 | 北京市博士后科研工作站管理办法 | 市级/人才支持 | 30 | 层级市级·领域人才支持 | — |
| 3 | 3 | 北京市技能大师工作室建设管理办法 | 市级/人才支持 | 30 | 层级市级·领域人才支持 | — |
| 4 | 4 | 北京市支持留学回国人才创新创业若干措施 | 市级/人才支持 | 30 | 层级市级·领域人才支持 | — |
| 5 | 5 | 北京市朝阳区高层次人才引进支持政策 | 区级/人才支持 | 30 | 层级区级·领域人才支持 | — |

## 申报条件对标分析

### 政策 1 - 北京市高层次创新创业人才支持计划科技新星计划管理办法
- 缺口项：无（以申报通知为准）

### 政策 2 - 北京市博士后科研工作站管理办法
- 缺口项：无（以申报通知为准）

### 政策 3 - 北京市技能大师工作室建设管理办法
- 缺口项：无（以申报通知为准）

### 政策 4 - 北京市支持留学回国人才创新创业若干措施
- 缺口项：无（以申报通知为准）

### 政策 5 - 北京市朝阳区高层次人才引进支持政策
- 缺口项：无（以申报通知为准）

## 申报建议与优先级

1. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市高层次创新创业人才支持计划科技新星计划管理办法（编号 1）
   - 支持方式：待补充
   - 建议关注 北京市科委 官网申报通知
2. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市博士后科研工作站管理办法（编号 2）
   - 支持方式：待补充
   - 建议关注 北京市人社局 官网申报通知
3. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市技能大师工作室建设管理办法（编号 3）
   - 支持方式：待补充
   - 建议关注 北京市人社局 官网申报通知
4. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市支持留学回国人才创新创业若干措施（编号 4）
   - 支持方式：待补充
   - 建议关注 北京市人社局 官网申报通知
5. 【高优先级】可申报（匹配度 30 分）
   - 政策：北京市朝阳区高层次人才引进支持政策（编号 5）
   - 支持方式：待补充
   - 建议关注 朝阳区人才工作局 官网申报通知

## 未查到可靠依据（已排除出正式结论）

以下 17 条线索**无法核验出处**（信源不可核验 / 已过时效 / 原文库不可用且非政府信源），
已按要求排除出正式结论，**不作为申报依据**：

| 序号 | 线索标题 | 排除原因 |
|------|---------|---------|
| 1 | 鼓楼区“数智链圈”四维赋能 打造园区发展新范式 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 2 | 入选改革发展最佳实践案例 “满天星”照亮重庆软信产业高地 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 3 | 佛山市人民政府办公室关于印发佛山市促进软件产业高质量发展行动方案的通知 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 4 | 超300家申请入驻 成都高新“一人公司”加速落地 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 5 | 我省推动软件产业由“外包大省”加速迈向“智能解决方案强省” | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 6 | 对区政协十一届五次会议第115029号提案的答复 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 7 | 广州首个智能体产业园正式揭牌,“TOKEN 8条”助力广州黄埔打造“龙虾”培育基地 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 8 | 最高补贴200万元 达州“真金白银”支持数字经济发展 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 9 | 深圳市龙岗区工业和信息化局政府信息公开 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 10 | 【甬派】智启未来④聚才､开源､共生!宁波正打造AI创新“热带雨林” | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 11 | 这里是“主场”·近观东西湖④当“小龙虾”游入“中国网谷”:折射网安信创产业新生态 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 12 | 音频解读:《达州市人民政府关于印发达州市加快数字经济高质量发展若干措施的通知》 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 13 | 《苏州市推进软件产业高质量发展行动计划(2026-2027年)》解读 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 14 | 宁波市鄞州区经济和信息化局关于区政协十七届五次会议第243号提案 的答复 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 15 | 广东省人民政府办公厅关于印发《广东省服务贸易高质量发展三年行动计划(2026—2028年)》的通知 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 16 | 宁波市鄞州区经济和信息化局关于区十九届人大五次会议第144号建议 的答复 | 未通过原文库交叉验证，无 policy_no 可绑定 |
| 17 | 荆门市人民政府 2026年 关于对市政协十届五次会议第24号提案的答复 | 未通过原文库交叉验证，无 policy_no 可绑定 |

## 合规声明

> 本报告由产业政策智能体自动生成，数据来源于公开渠道与政策知识库，每条匹配结论均已溯源至政策原文库编号；仅供申报参考，不构成法律意见。
', 'policy-match', 'completed', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-match"]'::jsonb, '{"profile_date": "2026-10-25", "matched_count": 74, "policy_nos": ["1", "2", "3"], "follow_status": "已完成", "report_file": "北京中关村软件园发展有限责任公司-2026-10-25.md"}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京中关村软件园发展有限责任公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策适配报告 - 北京中关村软件园发展有限责任公司' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 1 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '8d6223be-54a4-479d-936f-8bc7395a08e3', '政策申报 - 北京市高层次创新创业人才支持计划科技新星计划管理办法', '政策编号：1
支持方式：待补充
匹配依据：层级市级·领域人才支持
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "1", "domain": "人才支持", "level": "市级", "department": "北京市科委", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\1-北京市高层次创新创业人才支持计划科技新星计划管理办法.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京中关村软件园发展有限责任公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市高层次创新创业人才支持计划科技新星计划管理办法' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 2 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '687f1748-c645-46b9-aec8-4b13efd01909', '政策申报 - 北京市博士后科研工作站管理办法', '政策编号：2
支持方式：待补充
匹配依据：层级市级·领域人才支持
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "2", "domain": "人才支持", "level": "市级", "department": "北京市人社局", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\2-北京市博士后科研工作站管理办法.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京中关村软件园发展有限责任公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市博士后科研工作站管理办法' AND t.deleted_at IS NULL);

-- 截止时间未知：政策编号 3 未获取到明确截止日期，deadline 写 NULL，不作推测填充
INSERT INTO public.tasks (id, title, description, task_type, task_status, priority, company_id, creator_id, tags, extra_data, deadline, created_at, updated_at) SELECT '6f55ffd9-b8d9-44f7-b45a-422967e4a9b0', '政策申报 - 北京市技能大师工作室建设管理办法', '政策编号：3
支持方式：待补充
匹配依据：层级市级·领域人才支持
截止时间：截止时间未知（主管部门尚未公布或未获取到明确日期）
申报材料以主管部门通知为准。', 'policy-apply', 'open', 'normal', c.id, COALESCE((SELECT u.id FROM public.uctoo_user u WHERE u.deleted_at IS NULL ORDER BY u.created_at LIMIT 1), '00000000-0000-0000-0000-000000000000'::uuid), '["beichen", "policy-apply"]'::jsonb, '{"policy_no": "3", "domain": "人才支持", "level": "市级", "department": "北京市人社局", "deadline": null, "deadline_known": false, "follow_status": "待启动", "materials": ["以主管部门发布的申报通知为准"], "materials_source": "条目未提供材料清单，未作推测填充", "source": "policy-original/policy-original\\\\3-北京市技能大师工作室建设管理办法.md", "url": ""}'::jsonb, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM public.company c WHERE c.company_name = '北京中关村软件园发展有限责任公司' AND c.deleted_at IS NULL AND NOT EXISTS (  SELECT 1 FROM public.tasks t   WHERE t.company_id = c.id AND t.title = '政策申报 - 北京市技能大师工作室建设管理办法' AND t.deleted_at IS NULL);
