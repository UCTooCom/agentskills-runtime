### 📚 数据库表目录
 | 序号 | 表名 | 表说明 | 
 | :---: | :--- | :--- | 
 | 1 | [admin_applet](#admin_applet) | 当前管理的应用。支持统一平台管理多个应用，app、小程序、H5等，记录当前正在操作的应用。管理后台右上角切换当前管理的应用时，编辑此表数据。 | 
 | 2 | [ai_client](#ai_client) | AI客户端信息 | 
 | 3 | [app_access_token](#app_access_token) |  | 
 | 4 | [attachments](#attachments) | 上传资源表 | 
 | 5 | [cms_article_relate_tags](#cms_article_relate_tags) | 内容管理模块文章关联tag | 
 | 6 | [cms_articles](#cms_articles) | CMS文章表 | 
 | 7 | [cms_banners](#cms_banners) | 内容管理banner。 | 
 | 8 | [cms_category](#cms_category) | 内容类目 | 
 | 9 | [cms_comments](#cms_comments) | 内容评论 | 
 | 10 | [cms_form_data](#cms_form_data) | 动态表单数据 | 
 | 11 | [cms_form_fields](#cms_form_fields) | 动态表单字段 | 
 | 12 | [cms_forms](#cms_forms) | 动态表单 | 
 | 13 | [cms_model_auxiliary_table](#cms_model_auxiliary_table) | 动态模型表 | 
 | 14 | [cms_model_fields](#cms_model_fields) | 动态模型字段 | 
 | 15 | [cms_models](#cms_models) | 动态模型 | 
 | 16 | [cms_site_links](#cms_site_links) | 内容管理网站链接 | 
 | 17 | [cms_tags](#cms_tags) | 内容管理标签。不推荐使用。推荐统一使用tag表 | 
 | 18 | [codelabs](#codelabs) | 代码生成记录表 | 
 | 19 | [codelabs_algorithm](#codelabs_algorithm) | 代码生成算法 | 
 | 20 | [codelabs_templates](#codelabs_templates) | 代码生成模板 | 
 | 21 | [company](#company) | 公司信息 | 
 | 22 | [component_setting](#component_setting) |  | 
 | 23 | [config](#config) | 配置信息 | 
 | 24 | [crm_business_card](#crm_business_card) | 名片信息 | 
 | 25 | [crm_card_holder](#crm_card_holder) | 名片夹信息 | 
 | 26 | [crm_visit_log](#crm_visit_log) | 访客记录 | 
 | 27 | [crontab](#crontab) | 计划任务 | 
 | 28 | [crontab_log](#crontab_log) | 计划任务记录 | 
 | 29 | [customer_level](#customer_level) | 客户等级 | 
 | 30 | [customer_status](#customer_status) | 客户状态 | 
 | 31 | [customer_type](#customer_type) | 客户类型 | 
 | 32 | [data_access_authorization](#data_access_authorization) | 数据访问权限 | 
 | 33 | [db_connection](#db_connection) | 数据库连接 | 
 | 34 | [db_info](#db_info) | 数据库信息。屏蔽不同数据库差异，保存一致的数据库结构信息，便于可视化代码生成。可用于codelabs表的数据源data_source | 
 | 35 | [departments](#departments) | 部门信息 | 
 | 36 | [developer](#developer) | 开发者信息 | 
 | 37 | [developer_account](#developer_account) | 开发者实名信息 | 
 | 38 | [element_components](#element_components) | element UI组件信息 | 
 | 39 | [entity](#entity) | 实体信息 | 
 | 40 | [faq](#faq) | 常见问题 | 
 | 41 | [feedback](#feedback) | 反馈信息 | 
 | 42 | [group_has_permission](#group_has_permission) | 用户组所有权限 | 
 | 43 | [group_tag](#group_tag) | 组标签 | 
 | 44 | [guest_users](#guest_users) | 匿名用户，访客信息 | 
 | 45 | [jobs](#jobs) | 岗位信息 | 
 | 46 | [link](#link) | 链接信息 | 
 | 47 | [link_group](#link_group) | 链接分组 | 
 | 48 | [link_tag](#link_tag) | 链接标签关联 | 
 | 49 | [login_log](#login_log) | 登录记录 | 
 | 50 | [minishop_activity](#minishop_activity) | 商城活动 | 
 | 51 | [minishop_activity_goods_sku_price](#minishop_activity_goods_sku_price) | 商品活动价格 | 
 | 52 | [minishop_activity_groupon](#minishop_activity_groupon) | 活动成团信息 | 
 | 53 | [minishop_activity_groupon_log](#minishop_activity_groupon_log) | 拼团记录 | 
 | 54 | [minishop_address_info](#minishop_address_info) | 收件人地址信息 | 
 | 55 | [minishop_area](#minishop_area) | 省市区信息 | 
 | 56 | [minishop_cart](#minishop_cart) | 购物车信息 | 
 | 57 | [minishop_config](#minishop_config) | 商城配置 | 
 | 58 | [minishop_coupons](#minishop_coupons) | 商城优惠券 | 
 | 59 | [minishop_decorate](#minishop_decorate) | 商城模板信息 | 
 | 60 | [minishop_decorate_content](#minishop_decorate_content) | 页面模板装修数据 | 
 | 61 | [minishop_dispatch](#minishop_dispatch) | 配送方式 | 
 | 62 | [minishop_dispatch_autosend](#minishop_dispatch_autosend) | 自动发货 | 
 | 63 | [minishop_dispatch_express](#minishop_dispatch_express) | 发货信息 | 
 | 64 | [minishop_dispatch_selfetch](#minishop_dispatch_selfetch) | 自提数据 | 
 | 65 | [minishop_dispatch_store](#minishop_dispatch_store) | 自提店铺 | 
 | 66 | [minishop_express](#minishop_express) | 快递公司 | 
 | 67 | [minishop_failed_job](#minishop_failed_job) | 事务失败数据 | 
 | 68 | [minishop_goods_comment](#minishop_goods_comment) | 商品评论 | 
 | 69 | [minishop_goods_service](#minishop_goods_service) | 商品服务标识 | 
 | 70 | [minishop_link](#minishop_link) | 商城链接 | 
 | 71 | [minishop_order](#minishop_order) | 商城订单 | 
 | 72 | [minishop_order_action](#minishop_order_action) | 订单操作数据 | 
 | 73 | [minishop_order_aftersale](#minishop_order_aftersale) | 订单售后记录 | 
 | 74 | [minishop_order_aftersale_log](#minishop_order_aftersale_log) | 订单售后记录 | 
 | 75 | [minishop_order_detail](#minishop_order_detail) | 订单详情。数据结构与此文档一致 (https   developers.weixin.qq.com miniprogram dev platform-capabilities business-capabilities ministore minishopopencomponent API order get_order_detail.html) | 
 | 76 | [minishop_order_express](#minishop_order_express) | 订单快递信息 | 
 | 77 | [minishop_order_express_log](#minishop_order_express_log) | 订单快递记录 | 
 | 78 | [minishop_order_item](#minishop_order_item) | 订单详情 | 
 | 79 | [minishop_order_status](#minishop_order_status) | 订单状态枚举 | 
 | 80 | [minishop_product_category](#minishop_product_category) | 商品类目 | 
 | 81 | [minishop_refund_log](#minishop_refund_log) | 退款记录 | 
 | 82 | [minishop_share](#minishop_share) | 分享记录 | 
 | 83 | [minishop_shipping_method](#minishop_shipping_method) | 发货方式枚举 | 
 | 84 | [minishop_sku](#minishop_sku) | sku数据。与此文档数据结构一致(https   developers.weixin.qq.com miniprogram dev platform-capabilities business-capabilities ministore minishopopencomponent API sku get_sku.html) | 
 | 85 | [minishop_sku_attrs](#minishop_sku_attrs) | sku属性 | 
 | 86 | [minishop_sku_status](#minishop_sku_status) | sku状态 | 
 | 87 | [minishop_spu](#minishop_spu) | spu数据。与此文档一致(https   developers.weixin.qq.com miniprogram dev platform-capabilities business-capabilities ministore minishopopencomponent API spu get_spu.html) | 
 | 88 | [minishop_spu_edit_status](#minishop_spu_edit_status) | spu编辑状态枚举 | 
 | 89 | [minishop_spu_status](#minishop_spu_status) | spu状态枚举 | 
 | 90 | [minishop_store](#minishop_store) | 门店信息 | 
 | 91 | [minishop_store_apply](#minishop_store_apply) | 门店申请 | 
 | 92 | [minishop_user_address](#minishop_user_address) | 用户收获地址 | 
 | 93 | [minishop_user_bank](#minishop_user_bank) | 用户银行账户 | 
 | 94 | [minishop_user_coupons](#minishop_user_coupons) | 用户优惠券 | 
 | 95 | [minishop_user_favorite](#minishop_user_favorite) | 用户收藏 | 
 | 96 | [minishop_user_store](#minishop_user_store) | 用户所属门店 | 
 | 97 | [module_config](#module_config) | 模块配置信息 | 
 | 98 | [operate_log](#operate_log) | 操作记录 | 
 | 99 | [os_platform](#os_platform) | 操作系统 | 
 | 100 | [permissions](#permissions) | 权限 | 
 | 101 | [review](#review) |  | 
 | 102 | [sensitive_word](#sensitive_word) | 敏感词 | 
 | 103 | [sms_config](#sms_config) | 短信配置 | 
 | 104 | [sms_log](#sms_log) | 短信记录 | 
 | 105 | [sms_template](#sms_template) | 短信模板 | 
 | 106 | [tag](#tag) | 标签 | 
 | 107 | [uctoo_role](#uctoo_role) | 用户角色 | 
 | 108 | [uctoo_session](#uctoo_session) |  | 
 | 109 | [uctoo_user](#uctoo_user) | 用户表。相当于account。RBAC中的用户 | 
 | 110 | [unipay_applets](#unipay_applets) | 统一支付应用 | 
 | 111 | [unipay_config](#unipay_config) | 统一支付配置 | 
 | 112 | [user_group](#user_group) | 用户组 | 
 | 113 | [user_has_account](#user_has_account) |  | 
 | 114 | [user_has_group](#user_has_group) | 用户与组关联 | 
 | 115 | [user_has_jobs](#user_has_jobs) | 用户与职位关联 | 
 | 116 | [user_has_roles](#user_has_roles) | 用户与角色关联 | 
 | 117 | [user_messages](#user_messages) | 用户消息 | 
 | 118 | [user_role](#user_role) | 用户与角色关联 | 
 | 119 | [user_score](#user_score) | 用户积分 | 
 | 120 | [user_sign](#user_sign) | 打卡 | 
 | 121 | [user_view](#user_view) | 用户浏览商品记录 | 
 | 122 | [user_wallet_apply](#user_wallet_apply) | 用户提现 | 
 | 123 | [user_wallet_log](#user_wallet_log) | 用户提现记录 | 
 | 124 | [vmc](#vmc) | 自助售货机。无状态变化时 3-20分钟间隔上报，有状态变化时 立即上报。 | 
 | 125 | [vue_editor_items_config](#vue_editor_items_config) | vue编辑器控件配置 | 
 | 126 | [vue_editor_pages](#vue_editor_pages) | vue编辑器页面 | 
 | 127 | [wechat_cloud](#wechat_cloud) | 微信云 | 
 | 128 | [wechat_graphic](#wechat_graphic) | 微信图片 | 
 | 129 | [wechat_material](#wechat_material) | 微信素材 | 
 | 130 | [wechat_menus](#wechat_menus) | 微信公众号菜单 | 
 | 131 | [wechat_miniapp_version](#wechat_miniapp_version) | 小程序版本 | 
 | 132 | [wechat_reply](#wechat_reply) | 微信公众号消息 | 
 | 133 | [wechat_tags](#wechat_tags) | 微信标签 | 
 | 134 | [wechat_user_has_tags](#wechat_user_has_tags) | 微信用户标签 | 
 | 135 | [wechatopen](#wechatopen) | 微信第三方平台信息。详情参考 https   open.weixin.qq.com | 
 | 136 | [wechatopen_applet](#wechatopen_applet) | 微信第三方平台绑定的应用 | 
 | 137 | [wechatopen_miniapp_domains](#wechatopen_miniapp_domains) | 小程序域名配置 | 
 | 138 | [wechatopen_miniapp_users](#wechatopen_miniapp_users) | 小程序用户 | 
 | 139 | [wechatopen_template](#wechatopen_template) | 微信第三方平台小程序模板 | 
 | 140 | [wechatopen_template_draft](#wechatopen_template_draft) | 微信第三方平台小程序草稿箱 | 
 | 141 | [wechatopen_users](#wechatopen_users) | 公众号用户 | 
 | 142 | [wechatpay_transaction](#wechatpay_transaction) | 微信支付流水 | 
 | 143 | [wxa_updatable_message](#wxa_updatable_message) | 微信消息通知 | 
 | 144 | [agent_skills](#agent_skills) | Agent技能管理。用于管理Agent Skills运行时的技能包，支持从GitHub、Gitee、AtomGit等平台搜索和安装技能。 | 
| 145 | [agent_skill_executions](#agent_skill_executions) | Agent技能执行历史。记录技能的每次执行情况，包括参数、结果、执行时间等。 | 
| 146 | [agent_skill_configs](#agent_skill_configs) | Agent技能配置。存储技能的运行时配置项，支持动态配置管理。 | 
| 147 | [agent_runtime_status](#agent_runtime_status) | Agent运行时状态。监控Agent Skills运行时的运行状态、版本、端口等信息。 | 
| 148 | [chat_conversations](#chat_conversations) | 聊天会话表。存储智能体聊天会话的基本信息，包括模型配置、系统提示、状态等。 | 
| 149 | [chat_messages](#chat_messages) | 聊天消息表。存储聊天会话中的具体消息，包括角色、内容、令牌使用情况、技能执行信息等。 | 
### 📒 表结构

#### 表名： _prisma_migrations
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | id | varchar | (36) | √ |  |  |  |  | 
 | 2 | checksum | varchar | (64) |  |  |  |  |  | 
 | 3 | finished_at | timestamptz |  |  |  | √ |  |  | 
 | 4 | migration_name | varchar | (255) |  |  |  |  |  | 
 | 5 | logs | text |  |  |  | √ |  |  | 
 | 6 | rolled_back_at | timestamptz |  |  |  | √ |  |  | 
 | 7 | started_at | timestamptz |  |  |  |  | now |  | 
 | 8 | applied_steps_count | int4 |  |  |  |  | 0 |  | 

#### 表名： admin_applet
说明： 当前管理的应用。支持统一平台管理多个应用，app、小程序、H5等，记录当前正在操作的应用。管理后台右上角切换当前管理的应用时，编辑此表数据。
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | appid | text |  |  |  |  |  | appid。应用唯一id，关联WechatopenApplet表appid | 
 | 2 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 3 | status | int4 |  |  |  |  | 1 | 状态。1=当前操作的应用。0=非当前操作的应用。 | 
 | 4 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 5 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 

#### 表名： ai_client
说明： AI客户端信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | domain | varchar |  |  |  | √ |  | 域名 | 
 | 2 | username | varchar |  |  |  | √ |  | 用户名 | 
 | 3 | password | varchar |  |  |  | √ |  | 用户密码 | 
 | 4 | token | varchar |  |  |  |  |  | token | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | id | int4 |  | √ |  |  | 1 | id | 
 | 8 | token_overtime | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | token过期时间 | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： app_access_token
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | id | text |  | √ |  |  |  |  | 
 | 2 | access_token | varchar |  |  |  | √ |  |  | 
 | 3 | creator | uuid |  |  |  | √ |  |  | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  |  | 
 | 5 | token_overtime | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP |  | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP |  | 

#### 表名： attachments
说明： 上传资源表
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | path | varchar |  |  |  |  |  | 附件存储路径 | 
 | 2 | url | varchar |  |  |  |  |  | 资源URL地址 | 
 | 3 | mime_type | varchar |  |  |  |  |  | 资源mimeType | 
 | 4 | file_ext | varchar |  |  |  |  |  | 资源后缀 | 
 | 5 | filename | varchar |  |  |  |  |  | 资源名称 | 
 | 6 | driver | varchar |  |  |  |  |  | local,oss,qcloud,qiniu,huaweicloud | 
 | 7 | scene | varchar |  |  |  | √ |  | 场景值 | 
 | 8 | type | varchar |  |  |  | √ |  | 类型 | 
 | 9 | sc_id | int4 |  |  |  | √ |  | 内容安全id | 
 | 10 | ai_task_id | int4 |  |  |  | √ |  | AI任务id | 
 | 11 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 12 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 13 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 14 | filesize | int4 |  |  |  |  | 0 | 资源大小 | 
 | 15 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 16 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： cms_article_relate_tags
说明： 内容管理模块文章关联tag
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | article_id | uuid |  |  |  |  |  | 文章id。关联CMSArticles表id | 
 | 2 | tag_id | uuid |  |  |  |  |  | tag id。关联CmsTags表id | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid | id | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： cms_articles
说明： CMS文章表
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  | √ |  | 标题 | 
 | 2 | cover | varchar |  |  |  |  |  | 封面 | 
 | 3 | images | varchar |  |  |  |  |  | 内容banner多图 | 
 | 4 | url | varchar |  |  |  |  |  | 自定义文章url地址 | 
 | 5 | content | varchar |  |  |  |  |  | 文章详情。支持html，支持富文本编辑器 | 
 | 6 | keywords | varchar |  |  |  |  |  | 关键词 | 
 | 7 | description | varchar |  |  |  |  |  | 简介。用于分享时的副标题等 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 10 | category_id | uuid |  |  |  | √ |  | 分类ID。关联CmsCategory表id | 
 | 11 | id | uuid |  | √ |  |  | gen_random_uuid | id | 
 | 12 | pv | int4 |  |  |  |  | 0 | 浏览量 | 
 | 13 | likes | int4 |  |  |  |  | 0 | 点赞量 | 
 | 14 | comment_num | int4 |  |  |  |  | 0 | 评论数 | 
 | 15 | is_top | int4 |  |  |  |  | 0 | 是否置顶。0否。1是。 | 
 | 16 | is_recommend | int4 |  |  |  |  | 0 | 是否首页推荐。0否。1是。 | 
 | 17 | status | int4 |  |  |  |  | 0 | 状态。0 隐藏。1 展示  | 
 | 18 | weight | int4 |  |  |  |  | 0 | 文章权重。排序 | 
 | 19 | is_can_comment | int4 |  |  |  |  | 0 | 是否可以评论。0 不允许。1 允许  | 
 | 20 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 21 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： cms_banners
说明： 内容管理banner。
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | banner 标题 | 
 | 2 | banner_img | varchar |  |  |  |  |  | banner 图片 | 
 | 3 | category_id | uuid |  |  |  | √ |  | 关联CmsCategory表id。默认 0 代表首页展示。也可自定义首页组id | 
 | 4 | link_to | varchar |  |  |  | √ |  | 链接地址 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid | id | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： cms_category
说明： 内容类目
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  | √ |  | 栏目名称 | 
 | 2 | title | varchar |  |  |  |  |  | 标题 | 
 | 3 | keywords | varchar |  |  |  | √ |  | 关键词 | 
 | 4 | description | varchar |  |  |  |  |  | 描述 | 
 | 5 | url | varchar |  |  |  |  |  | 自定义 URL | 
 | 6 | link_to | varchar |  |  |  | √ |  | 链接外部地址 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | parent_id | uuid |  |  |  | √ |  |  | 
 | 10 | id | uuid |  | √ |  |  | gen_random_uuid | id | 
 | 11 | status | int4 |  |  |  |  | 0 | 状态。0隐藏。1显示 | 
 | 12 | is_can_contribute | int4 |  |  |  |  | 0 | 是否可以投稿。0否。1是。 | 
 | 13 | is_can_comment | int4 |  |  |  |  | 0 | 是否可以评论。0否。1是。 | 
 | 14 | type | int4 |  |  |  |  | 0 | 页面模式 | 
 | 15 | weight | int4 |  |  |  |  | 0 | 权重 | 
 | 16 | limit | int4 |  |  |  |  | 0 | 每页数量 | 
 | 17 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 18 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： cms_comments
说明： 内容评论
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | article_id | uuid |  |  |  |  |  | 文章id | 
 | 2 | content | varchar |  |  |  |  |  | 内容 | 
 | 3 | user_id | uuid |  |  |  |  |  | 评论者ID | 
 | 4 | ip | uuid |  |  |  |  |  | ip 地址 | 
 | 5 | user_agent | varchar |  |  |  | √ |  | agent | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | parent_id | uuid |  |  |  | √ |  |  | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid | id | 
 | 10 | status | int4 |  |  |  |  | 0 | 状态。1 展示 0 隐藏 | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： cms_form_data
说明： 动态表单数据
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | form_id | uuid |  |  |  |  |  | 表单ID。关联CmsForms表id | 
 | 2 | form_data | varchar |  |  |  |  |  | 数据内容。json字段 | 
 | 3 | user_id | uuid |  |  |  |  |  | 用户ID | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | ip | uuid |  |  |  |  |  | ip 地址 | 
 | 6 | user_agent | varchar |  |  |  | √ |  | 客户端agent | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： cms_form_fields
说明： 动态表单字段
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | form_id | uuid |  |  |  |  |  | form id | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | default_value | varchar |  |  |  |  |  | 默认值 | 
 | 5 | failed_message | varchar |  |  |  |  |  | 验证失败信息 | 
 | 6 | label | varchar |  |  |  |  |  | 字段 label | 
 | 7 | name | varchar |  |  |  |  |  | 表单字段name | 
 | 8 | rule | varchar |  |  |  |  |  | 验证规则 | 
 | 9 | type | varchar |  |  |  |  |  | 类型 | 
 | 10 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 13 | length | int4 |  |  |  |  | 0 | 字段长度 | 
 | 14 | status | int4 |  |  |  |  | 0 | 状态。1 展示 0 隐藏 | 

#### 表名： cms_forms
说明： 动态表单
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 表单名称 | 
 | 2 | alias | varchar |  |  |  | √ |  | 表单别名 | 
 | 3 | submit_url | varchar |  |  |  |  |  | 表单提交的 URL | 
 | 4 | title | varchar |  |  |  |  |  | 表单标题 | 
 | 5 | keywords | varchar |  |  |  |  |  | 关键词 | 
 | 6 | description | varchar |  |  |  |  |  | 描述 | 
 | 7 | success_message | varchar |  |  |  |  |  | 成功提示信息 | 
 | 8 | failed_message | varchar |  |  |  |  |  | 失败提示信息 | 
 | 9 | success_link_to | varchar |  |  |  |  |  | 成功后跳转url | 
 | 10 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 11 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 12 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 13 | is_login_to_submit | int4 |  |  |  |  | 1 | 是否需登录。1 需要 0 不需要 | 
 | 14 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 15 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： cms_model_auxiliary_table
说明： 动态模型表
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | model_id | uuid |  |  |  |  |  | 模型ID | 
 | 2 | alias | varchar |  |  |  |  |  | 模型别名 | 
 | 3 | table_name | varchar |  |  |  |  |  | 副表表明 | 
 | 4 | description | varchar |  |  |  |  |  | 模型关联的表名,数据来源 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 10 | used | int4 |  |  |  |  | 1 | 默认使用。 0 不使用 1 使用 | 

#### 表名： cms_model_fields
说明： 动态模型字段
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 字段中文名称 | 
 | 2 | name | varchar |  |  |  |  |  | 表单字段名称 | 
 | 3 | type | varchar |  |  |  |  |  | 类型 | 
 | 4 | length | varchar |  |  |  | √ |  | 字段长度 | 
 | 5 | default_value | varchar |  |  |  |  |  | 默认值 | 
 | 6 | options | varchar |  |  |  |  |  | 选项 | 
 | 7 | rules | varchar |  |  |  | √ |  | 验证规则 | 
 | 8 | pattern | varchar |  |  |  | √ |  | 正则 | 
 | 9 | model_id | uuid |  |  |  |  |  | 模型ID | 
 | 10 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 11 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 12 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 13 | is_index | int4 |  |  |  |  | 0 | 是否是索引。 1 是 0 否 | 
 | 14 | is_unique | int4 |  |  |  |  | 0 | 是否唯一。 1 是 0 否 | 
 | 15 | weight | int4 |  |  |  |  | 0 | 排序 | 
 | 16 | status | int4 |  |  |  |  | 0 | 状态 1显示 0隐藏 | 
 | 17 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 18 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 19 | used_at_detail | int4 |  |  |  |  | 1 | 展示在详情 1 是 0 否 | 
 | 20 | used_at_search | int4 |  |  |  |  | 1 | 用作是否搜索 1 是 0 否 | 
 | 21 | used_at_list | int4 |  |  |  |  | 1 | 展示在列表 1 是 0 否 | 

#### 表名： cms_models
说明： 动态模型
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 模型名称 | 
 | 2 | alias | varchar |  |  |  |  |  | 模型别名 | 
 | 3 | table_name | varchar |  |  |  |  |  | 模型关联的表名,数据来源 | 
 | 4 | description | varchar |  |  |  |  |  | 模型描述 | 
 | 5 | used_at_detail | varchar |  |  |  |  |  | 用在详情的字段 | 
 | 6 | used_at_search | varchar |  |  |  |  |  | 用在搜索的字段 | 
 | 7 | used_at_list | varchar |  |  |  |  |  | 用在列表的字段 | 
 | 8 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 9 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 10 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： cms_site_links
说明： 内容管理网站链接
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 友情链接标题 | 
 | 2 | link_to | varchar |  |  |  |  |  | 跳转地址 | 
 | 3 | icon | varchar |  |  |  |  |  | 网站图标 | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | weight | int4 |  |  |  |  | 0 | 权重 | 
 | 8 | is_show | int4 |  |  |  |  | 1 | 是否显示。1 展示 0 隐藏 | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： cms_tags
说明： 内容管理标签。不推荐使用。推荐统一使用tag表
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 标签名称 | 
 | 2 | title | varchar |  |  |  |  |  | seo 标题 | 
 | 3 | keywords | varchar |  |  |  |  |  | 关键字 | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | description | int4 |  |  |  |  | 0 | 描述 | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： codelabs
说明： 代码生成记录表
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | command | varchar |  |  |  |  |  | 命令名称 | 
 | 2 | arguments | varchar |  |  |  | √ |  | 命令参数。json格式 | 
 | 3 | data_structure | varchar |  |  |  | √ |  | 数据结构 | 
 | 4 | template_code | varchar |  |  |  | √ |  | 模板代码 | 
 | 5 | config_data | varchar |  |  |  | √ |  | 用户配置 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | algorithm | varchar |  |  |  | √ |  | 算法 | 
 | 8 | result | varchar |  |  |  | √ |  | 结果 | 
 | 9 | input | varchar |  |  |  | √ |  | 输入配置 | 
 | 10 | output | varchar |  |  |  | √ |  | 输出配置 | 
 | 11 | remark | varchar |  |  |  | √ |  | 备注 | 
 | 12 | template_file | varchar |  |  |  | √ |  | 模板文件 | 
 | 13 | data_source | varchar |  |  |  | √ |  | 数据源 | 
 | 14 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 15 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 16 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 17 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： codelabs_algorithm
说明： 代码生成算法
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | command_name | varchar |  |  |  |  |  | 命令名称 | 
 | 2 | algorithm_code | varchar |  |  |  | √ |  | 算法代码 | 
 | 3 | filename | varchar |  |  |  | √ |  | 算法文件名 | 
 | 4 | filepath | varchar |  |  |  | √ |  | 算法文件路径 | 
 | 5 | template_url | varchar |  |  |  | √ |  | 算法url地址 | 
 | 6 | author | varchar |  |  |  | √ |  | 作者 | 
 | 7 | author_url | varchar |  |  |  | √ |  | 作者url | 
 | 8 | user_id | uuid |  |  |  | √ |  | 用户id。关联user表id | 
 | 9 | tags | varchar |  |  |  | √ |  | 算法标签 | 
 | 10 | docs | varchar |  |  |  | √ |  | 算法文档 | 
 | 11 | images | varchar |  |  |  | √ |  | 算法图片 | 
 | 12 | description | varchar |  |  |  | √ |  | 算法描述 | 
 | 13 | arguments | varchar |  |  |  | √ |  | 命令参数。json格式 | 
 | 14 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 15 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 16 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 17 | opensource | int4 |  |  |  | √ | 0 | 是否开源 | 
 | 18 | price | float8 |  |  |  | √ | 0 | 算法标价 | 
 | 19 | status | int4 |  |  |  | √ | 0 | 算法状态 | 
 | 20 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 21 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： codelabs_templates
说明： 代码生成模板
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 模板名称 | 
 | 2 | template_code | varchar |  |  |  | √ |  | 模板代码 | 
 | 3 | filename | varchar |  |  |  | √ |  | 模板文件名 | 
 | 4 | filepath | varchar |  |  |  | √ |  | 模板路径 | 
 | 5 | config_header | varchar |  |  |  | √ |  | 模板配置表头 | 
 | 6 | config_json | varchar |  |  |  | √ |  | 模板配置项 | 
 | 7 | template_url | varchar |  |  |  | √ |  | 模板url地址 | 
 | 8 | author | varchar |  |  |  | √ |  | 作者 | 
 | 9 | author_url | varchar |  |  |  | √ |  | 作者url | 
 | 10 | user_id | uuid |  |  |  | √ |  | 用户id。关联user表id | 
 | 11 | tags | varchar |  |  |  | √ |  | 模板标签 | 
 | 12 | docs | varchar |  |  |  | √ |  | 模板文档 | 
 | 13 | images | varchar |  |  |  | √ |  | 模板图片 | 
 | 14 | description | varchar |  |  |  | √ |  | 模板描述 | 
 | 15 | arguments | varchar |  |  |  | √ |  | 模板参数 | 
 | 16 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 17 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 18 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 19 | opensource | int4 |  |  |  | √ | 0 | 是否开源 | 
 | 20 | price | float8 |  |  |  | √ | 0 | 模板标价 | 
 | 21 | status | int4 |  |  |  | √ | 0 | 模板状态 | 
 | 22 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 23 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： company
说明： 公司信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | company_name | varchar |  |  |  |  |  | 公司名称 | 
 | 2 | region | varchar |  |  |  |  |  | 公司所在地 | 
 | 3 | social_credit_code | varchar |  |  |  |  |  | 统一社会信用代码 | 
 | 4 | established_time | varchar |  |  |  |  |  | 注册时间 | 
 | 5 | registered_capital | varchar |  |  |  |  |  | 注册资本 | 
 | 6 | registered_address | varchar |  |  |  |  |  | 注册地址 | 
 | 7 | mailing_address | varchar |  |  |  |  |  | 通信地址 | 
 | 8 | legal_representative | varchar |  |  |  |  |  | 法人姓名 | 
 | 9 | legal_representativeMobile | varchar |  |  |  |  |  | 法人手机号 | 
 | 10 | legal_representative_email | varchar |  |  |  |  |  | 法人邮箱 | 
 | 11 | contact_name | varchar |  |  |  |  |  | 联系人姓名 | 
 | 12 | contact_mobile | varchar |  |  |  |  |  | 联系人手机号 | 
 | 13 | contact_email | varchar |  |  |  |  |  | 联系人邮箱 | 
 | 14 | contact_title | varchar |  |  |  |  |  | 联系人职务 | 
 | 15 | website | varchar |  |  |  |  |  | 官方网址 | 
 | 16 | company_logo | varchar |  |  |  | √ |  | 公司logo | 
 | 17 | associated_project_manager | varchar |  |  |  | √ |  | 关联客户代表 | 
 | 18 | company_introduction | varchar |  |  |  |  |  | 公司介绍 | 
 | 19 | business_licence | varchar |  |  |  |  |  | 公司营业执照 | 
 | 20 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 21 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 22 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 23 | verified | int4 |  |  |  |  | 0 | 企业实名认证 | 
 | 24 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 25 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： component_setting
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | table_catalog | varchar |  |  |  |  |  |  | 
 | 2 | table_schema | varchar |  |  |  | √ |  |  | 
 | 3 | table_name | varchar |  |  |  |  |  |  | 
 | 4 | page_name | varchar |  |  |  | √ |  |  | 
 | 5 | component_name | varchar |  |  |  | √ |  |  | 
 | 6 | route | varchar |  |  |  | √ |  |  | 
 | 7 | selected_table_column | varchar |  |  |  | √ |  |  | 
 | 8 | selected_form_column | varchar |  |  |  | √ |  |  | 
 | 9 | creator | uuid |  |  |  | √ |  |  | 
 | 10 | deleted_at | timestamptz |  |  |  | √ |  |  | 
 | 11 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP |  | 
 | 13 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP |  | 

#### 表名： config
说明： 配置信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 配置名称 | 
 | 2 | parent_id | uuid |  |  |  | √ |  | 父级配置 | 
 | 3 | component | varchar |  |  |  |  |  | tab 引入的组件名称 | 
 | 4 | key | varchar |  |  |  |  |  | 配置键名 | 
 | 5 | value | varchar |  |  |  | √ |  | 配置键值 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | status | int4 |  |  |  |  | 1 | 状态。1 启用 0 禁用 | 
 | 10 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 11 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： crm_business_card
说明： 名片信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | uid | uuid |  |  |  |  |  | 关联各用户表的id | 
 | 2 | umodel | varchar |  |  |  |  |  | 关联模型名 | 
 | 3 | realname | varchar |  |  |  |  |  | 真实名字 | 
 | 4 | gender | varchar |  |  |  | √ |  | 性别 | 
 | 5 | cover | varchar |  |  |  | √ |  | 封面图片 | 
 | 6 | job_title | varchar |  |  |  | √ |  | 职位 | 
 | 7 | sub_title | varchar |  |  |  | √ |  | 副职位 | 
 | 8 | organization | varchar |  |  |  | √ |  | 企业组织名称 | 
 | 9 | org_logo | varchar |  |  |  | √ |  | 企业组织logo | 
 | 10 | mobile | varchar |  |  |  | √ |  | 移动电话号码 | 
 | 11 | wechat | varchar |  |  |  | √ |  | 微信号 | 
 | 12 | address | varchar |  |  |  | √ |  | 地址 | 
 | 13 | email | varchar |  |  |  | √ |  | 邮箱 | 
 | 14 | attrs | varchar |  |  |  | √ |  | 更多字段 | 
 | 15 | nanoid | varchar |  |  |  |  |  | 页面nanoid | 
 | 16 | phone | varchar |  |  |  | √ |  | 固定电话号码 | 
 | 17 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 18 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 19 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 20 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 21 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： crm_card_holder
说明： 名片夹信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | holder_uid | uuid |  |  |  |  |  | 名片夹所有者uid | 
 | 2 | holder_umodel | varchar |  |  |  |  |  | 名片夹所有者umodel | 
 | 3 | card_uid | uuid |  |  |  |  |  | 名片uid | 
 | 4 | card_umodel | varchar |  |  |  |  |  | 名片umodel | 
 | 5 | nanoid | varchar |  |  |  |  |  | 名片nanoid | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | weight | int4 |  |  |  |  | 0 | 排序 | 
 | 10 | status | int4 |  |  |  |  | 0 | 状态 1=展示;0=隐藏 | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： crm_visit_log
说明： 访客记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | from_uid | uuid |  |  |  |  |  | 来访者uid | 
 | 2 | from_umodel | varchar |  |  |  |  |  | 来访者模型 | 
 | 3 | to_uid | uuid |  |  |  |  |  | 受访者uid | 
 | 4 | to_umodel | varchar |  |  |  |  |  | 受访者模型 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： crontab
说明： 计划任务
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 任务名称 | 
 | 2 | task | varchar |  |  |  |  |  | 任务名称 | 
 | 3 | cron | varchar |  |  |  |  |  | cron 表达式 | 
 | 4 | tactics | varchar |  |  |  |  |  | 策略。1 立即执行 2 执行一次 3 放弃执行 | 
 | 5 | remark | varchar |  |  |  |  |  | 备注 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | group | varchar |  |  |  |  | 1 | 分组。1 默认 2 系统 | 
 | 10 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 11 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 12 | status | int4 |  |  |  |  | 1 | 状态。1 正常 2 禁用 | 

#### 表名： crontab_log
说明： 计划任务记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | crontab_id | uuid |  |  |  |  |  | crontab 任务ID | 
 | 2 | error_message | varchar |  |  |  |  |  | 错误信息 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | used_time | int4 |  |  |  |  | 0 | 任务消耗时间 | 
 | 7 | status | int4 |  |  |  |  | 1 | 状态。1 成功 0 失败 | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： customer_level
说明： 客户等级
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 等级唯一英文名 | 
 | 2 | title | varchar |  |  |  |  |  | 等级中文标题 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： customer_status
说明： 客户状态
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 状态唯一英文名 | 
 | 2 | title | varchar |  |  |  |  |  | 状态中文标题 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： customer_type
说明： 客户类型
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 客户类型名(英文唯一) | 
 | 2 | title | varchar |  |  |  |  |  | 类型中文标题 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： data_access_authorization
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | entity_type | varchar | (50) |  |  |  |  |  | 
 | 2 | user_id | uuid |  |  |  |  |  |  | 
 | 3 | permission | int4 |  |  |  |  |  |  | 
 | 4 | creator | uuid |  |  |  | √ |  |  | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  |  | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP |  | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP |  | 
 | 9 | entity_id | varchar |  |  |  |  |  |  | 

#### 表名： db_connection
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | provider | varchar |  |  |  |  |  |  | 
 | 2 | user | varchar |  |  |  |  |  |  | 
 | 3 | password | varchar |  |  |  |  |  |  | 
 | 4 | host | varchar |  |  |  |  |  |  | 
 | 5 | port | varchar |  |  |  |  |  |  | 
 | 6 | database_name | varchar |  |  |  |  |  |  | 
 | 7 | creator | uuid |  |  |  | √ |  |  | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  |  | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | ssl | int4 |  |  |  |  | 0 |  | 
 | 11 | type | varchar |  |  |  | √ | ''::character varying |  | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP |  | 
 | 13 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP |  | 

#### 表名： db_info
说明： 数据库信息。屏蔽不同数据库差异，保存一致的数据库结构信息，便于可视化代码生成。可用于codelabs表的数据源data_source
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | table_catalog | varchar |  |  |  |  |  | 表分组。即数据库名 | 
 | 2 | table_schema | varchar |  |  |  | √ |  | table_schema | 
 | 3 | table_name | varchar |  |  |  |  |  | 表名 | 
 | 4 | column_name | varchar |  |  |  |  |  | 列名 | 
 | 5 | column_default | varchar |  |  |  | √ |  | 默认值 | 
 | 6 | data_type | varchar |  |  |  | √ |  | 数据类型 | 
 | 7 | rules | varchar |  |  |  | √ |  | 校验规则 | 
 | 8 | pattern | varchar |  |  |  | √ |  | 正则表达式 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid | id | 
 | 10 | is_nullable | varchar |  |  |  |  | 'YES'::character varying | 是否可空。YES可空，NO不可空。 | 
 | 11 | vue_component_type | varchar |  |  |  | √ | 'textarea'::character varying | vue控件类型。一般用于生成PC端管理后台代码。 | 
 | 12 | react_component_type | varchar |  |  |  | √ | 'textarea'::character varying | vue控件类型。一般用于生成PC端管理后台代码。 | 
 | 13 | arkui_component_type | varchar |  |  |  | √ | 'TextArea'::character varying | arkui控件类型。一般用于生成鸿蒙原生应用代码。 | 
 | 14 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 15 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 16 | placeholder | varchar |  |  |  | √ |  | 占位符或tips | 
 | 17 | column_comment | varchar |  |  |  | √ |  | 列备注 | 
 | 18 | uniapp_component_type | varchar |  |  |  | √ | 'textarea'::character varying | uniapp控件类型。一般用于生成小程序应用代码。 | 
 | 19 | weight | int4 |  |  |  |  | 0 | 排序 | 
 | 20 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 21 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 22 | is_column_hidden | varchar |  |  |  |  | 'NO'::character varying | 字段是否隐藏。YES=隐藏，NO=显示。 | 
 | 23 | is_table_hidden | varchar |  |  |  |  | 'NO'::character varying | 表是否隐藏。YES=隐藏，NO=显示。由于是字段表，因此这个字段存在冗余，应保持同一个表在多条字段记录中此值一致。 | 
 | 24 | ordinal_position | int4 |  |  |  |  | 0 | 列的顺序位置 | 
 | 25 | migration_id | varchar |  |  |  | √ | 'dev'::character varying | 关联_prisma_migrations表id。可作为数据库版本管理标识。 | 
 | 26 | character_maximum_length | int8 |  |  |  | √ | 11 |  | 

#### 表名： departments
说明： 部门信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | department_name | varchar |  |  |  |  |  | 部门名称 | 
 | 2 | parent_id | uuid |  |  |  | √ |  | 父级ID | 
 | 3 | principal | varchar |  |  |  | √ |  | 负责人 | 
 | 4 | mobile | varchar |  |  |  |  |  | 联系电话 | 
 | 5 | email | varchar |  |  |  |  |  | 联系邮箱 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | weight | int4 |  |  |  |  | 0 | 排序 | 
 | 10 | status | int4 |  |  |  |  | 1 | 状态。1 正常 0 停用 | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： developer
说明： 开发者信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | mobile | varchar |  |  |  |  |  | 手机号 | 
 | 3 | id_card | varchar |  |  |  |  |  | 身份证 | 
 | 4 | alipay_account | varchar |  |  |  |  |  | 支付宝账户 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | status | int4 |  |  |  |  | 0 | 状态。0 待认证 1 已认证 | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： developer_account
说明： 开发者实名信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | varchar |  |  |  |  |  | 关联user表id | 
 | 2 | wechat_miniapp_user_id | varchar |  |  |  |  |  | 关联wechat_mMiniappUser_id表id | 
 | 3 | realname | varchar |  |  |  |  |  | 真实姓名 | 
 | 4 | mobile | varchar |  |  |  |  |  | 手机号 | 
 | 5 | idcard1 | varchar |  |  |  |  |  | 身份证正面 | 
 | 6 | idcard2 | varchar |  |  |  |  |  | 身份证反面 | 
 | 7 | business_license | varchar |  |  |  | √ |  | 营业执照 | 
 | 8 | wechat_openid | varchar |  |  |  |  |  | 微信openid（个人结算） | 
 | 9 | mchid | varchar |  |  |  | √ |  | 微信支付商户号（企业结算） | 
 | 10 | alipay_user_Id | varchar |  |  |  | √ |  | 支付宝个人帐号（个人结算） | 
 | 11 | alipay_login_name | varchar |  |  |  | √ |  | 支付宝登录号 | 
 | 12 | company_name | varchar |  |  |  | √ |  | 公司名称 | 
 | 13 | company_address | varchar |  |  |  | √ |  | 公司地址 | 
 | 14 | company_contact | varchar |  |  |  | √ |  | 公司联系方式 | 
 | 15 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 16 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 17 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 18 | type | int4 |  |  |  |  | 0 | 帐号类型 1=企业,2=个人 | 
 | 19 | status | int4 |  |  |  |  | 0 | 认证状态。1=待认证,2=已认证 | 
 | 20 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 21 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： element_components
说明： element UI组件信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 组件名。与https   github.com ElemeFE element blob master components.json一致 | 
 | 2 | tag | varchar |  |  |  |  |  | 组件标签 | 
 | 3 | docs_url | varchar |  |  |  |  |  | 组件文档url地址 | 
 | 4 | specification | varchar |  |  |  |  |  | 组件规范json。包含组件Attributes的全量信息 | 
 | 5 | version | varchar |  |  |  | √ |  | 版本 | 
 | 6 | remarks | varchar |  |  |  | √ |  | 备注 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | status | int4 |  |  |  |  | 0 | 状态 | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： entity
说明： 实体信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | link | varchar |  |  |  |  |  | 链接url | 
 | 2 | description | varchar |  |  |  | √ |  | 描述 | 
 | 3 | group_id | uuid |  |  |  | √ |  | 分组id | 
 | 4 | content | text |  |  |  | √ |  | 内容 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | privacy_level | int4 |  |  |  |  | 0 | 隐私等级 | 
 | 7 | stars | float8 |  |  |  |  | 0 | 星级 | 
 | 8 | picture | varchar |  |  |  | √ | ''::character varying | 单图 | 
 | 9 | json | text |  |  |  | √ |  | json内容 | 
 | 10 | city | varchar |  |  |  | √ |  | 城市 | 
 | 11 | birthday | date |  |  |  | √ |  | 生日 | 
 | 12 | owner | varchar |  |  |  | √ |  | 所属用户。关联user表username | 
 | 13 | creator | uuid |  |  |  |  |  | 创建人 | 
 | 14 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 15 | images | varchar |  |  |  | √ | ''::character varying | 多图 | 
 | 16 | price | float8 |  |  |  | √ | 0 | 价格 | 
 | 17 | start_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP |  | 
 | 18 | end_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP |  | 
 | 19 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 20 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 21 | status | varchar |  |  |  | √ |  |  | 

#### 表名： faq
说明： 常见问题
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 标题 | 
 | 2 | content | varchar |  |  |  |  |  | 内容 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： feedback
说明： 反馈信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | type | varchar |  |  |  | √ |  | 反馈类型 | 
 | 3 | content | varchar |  |  |  | √ |  | 反馈内容 | 
 | 4 | images | varchar |  |  |  | √ |  | 图片 | 
 | 5 | phone | varchar |  |  |  | √ |  | 联系电话 | 
 | 6 | remark | varchar |  |  |  | √ |  | 处理备注 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | status | int4 |  |  |  |  | 0 | 是否处理。0=未处理,1=已处理 | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： group_has_permission
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | group_id | uuid |  | √ |  |  |  |  | 
 | 2 | permission_name | text |  | √ |  |  |  |  | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | status | int4 |  |  |  |  | 0 |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： group_tag
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | group_id | uuid |  |  |  |  |  |  | 
 | 2 | tagId | uuid |  |  |  |  |  |  | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： guest_users
说明： 匿名用户，访客信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | nickname | varchar |  |  |  | √ |  | 昵称 | 
 | 2 | token | varchar |  |  |  | √ |  | token | 
 | 3 | domain | varchar |  |  |  | √ |  | 来源域名 | 
 | 4 | ipAddress | varchar |  |  |  | √ |  | ip地址 | 
 | 5 | userAgent | varchar |  |  |  | √ |  | 用户端类型 | 
 | 6 | referer | varchar |  |  |  | √ |  | 来源网址 | 
 | 7 | mobile | varchar |  |  |  | √ |  | 手机号码 | 
 | 8 | channel | varchar |  |  |  | √ |  | 来源渠道 | 
 | 9 | comments | varchar |  |  |  | √ |  | 备注 | 
 | 10 | user_id | uuid |  |  |  | √ |  | 关联用户id | 
 | 11 | user_model | varchar |  |  |  | √ |  | 关联用户模型 | 
 | 12 | appid | varchar |  |  |  | √ |  | appid | 
 | 13 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 14 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 15 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 16 | lastAccessTime | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 最近访问时间 | 
 | 17 | status | int4 |  |  |  | √ | 0 | 状态 | 
 | 18 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 19 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： jobs
说明： 岗位信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | job_name | varchar |  |  |  |  |  | 岗位名称 | 
 | 2 | coding | varchar |  |  |  |  |  | 编码 | 
 | 3 | description | varchar |  |  |  |  |  | 描述 | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | weight | int4 |  |  |  |  | 0 | 排序 | 
 | 8 | status | int4 |  |  |  |  | 1 | 1 正常 0 停用 | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： link
说明： 链接信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | link | varchar |  |  |  |  |  | 链接url | 
 | 2 | owner | uuid |  |  |  | √ |  | 所有者。关联user表username | 
 | 3 | description | varchar |  |  |  | √ |  | 描述 | 
 | 4 | group_id | uuid |  |  |  | √ |  | 分组id | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | privacy_cevel | int4 |  |  |  |  | 0 | 隐私等级 | 
 | 9 | stars | float8 |  |  |  |  | 0 | 星级 | 
 | 10 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 11 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： link_group
说明： 链接分组
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | owner | varchar |  |  |  |  |  | 归属用户。关联user表username | 
 | 2 | groupname | varchar |  |  |  |  |  | 分组名 | 
 | 3 | name | varchar |  |  |  |  |  | 组名。英文唯一描述 | 
 | 4 | description | varchar |  |  |  |  |  | 描述 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | picture | varchar |  |  |  |  | ''::character varying | 图片 | 
 | 9 | stars | float8 |  |  |  |  | 0 | 星级 | 
 | 10 | watcher_count | int4 |  |  |  |  | 0 | 浏览数 | 
 | 11 | linked_count | int4 |  |  |  |  | 0 | 被链接数 | 
 | 12 | links_count | int4 |  |  |  |  | 0 | 链接数量 | 
 | 13 | privacy_level | int4 |  |  |  |  | 0 | 隐私等级 | 
 | 14 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 15 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： link_tag
说明： 链接标签关联
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | link_id | uuid |  |  |  |  |  | 链接id | 
 | 2 | tag_id | uuid |  |  |  |  |  | 标签id | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： login_log
说明： 登录记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | login_name | varchar |  |  |  |  |  | 用户名 | 
 | 2 | login_ip | varchar |  |  |  |  |  | 登录地点ip | 
 | 3 | browser | varchar |  |  |  |  |  | 浏览器 | 
 | 4 | os | varchar |  |  |  |  |  | 操作系统 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | login_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 登录时间 | 
 | 9 | status | int4 |  |  |  |  | 0 | 状态。1 成功 0 失败 | 
 | 10 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 11 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_activity
说明： 商城活动
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 活动名称 | 
 | 2 | goods_ids | varchar |  |  |  |  |  | 商品id | 
 | 3 | type | varchar |  |  |  | √ |  | 类型 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | richtext_title | varchar |  |  |  | √ |  | 说明标题 | 
 | 6 | rules | varchar |  |  |  | √ |  | 活动规则 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | richtext_id | varchar |  |  |  | √ |  |  | 
 | 10 | sharde_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 开始时间 | 
 | 11 | end_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 结束时间 | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 13 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_activity_goods_sku_price
说明： 商品活动价格
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | activity_id | uuid |  |  |  |  |  | 活动id | 
 | 2 | sku_price_id | uuid |  |  |  |  |  | 规格id | 
 | 3 | goods_id | uuid |  |  |  |  |  | 所属产品 | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | stock | int4 |  |  |  |  | 0 | 库存 | 
 | 8 | sales | int4 |  |  |  |  | 0 | 已售 | 
 | 9 | price | float8 |  |  |  | √ | 0 | 活动价格 | 
 | 10 | status | int4 |  |  |  |  | 0 | 状态 | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_activity_groupon
说明： 活动成团信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id。团长 | 
 | 2 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 3 | goods_id | uuid |  |  |  |  |  | 商品 | 
 | 4 | activity_id | uuid |  |  |  |  |  | 活动id | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | status | varchar |  |  |  |  |  | 状态。invalid=已过期,ing=进行中,finish=已成团,finish-fictitious=虚拟成团 | 
 | 8 | num | int4 |  |  |  |  | 0 | 成团人数 | 
 | 9 | current_num | int4 |  |  |  |  | 0 | 当前人数 | 
 | 10 | expire_time | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 过期时间 | 
 | 11 | finish_time | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 成团时间 | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 13 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_activity_groupon_log
说明： 拼团记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | user_nickname | varchar |  |  |  | √ |  | 用户昵称 | 
 | 3 | user_avatar | varchar |  |  |  | √ |  | 头像 | 
 | 4 | groupon_id | uuid |  |  |  |  |  | 拼团活动id | 
 | 5 | goods_id | uuid |  |  |  |  |  | 商品id | 
 | 6 | goods_sku_price_id | uuid |  |  |  |  |  | 商品规格 | 
 | 7 | activity_id | uuid |  |  |  |  |  | 活动id | 
 | 8 | order_id | uuid |  |  |  |  |  | 订单id | 
 | 9 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 10 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 11 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 12 | is_leader | int4 |  |  |  |  | 0 | 是否团长 | 
 | 13 | is_fictitious | int4 |  |  |  |  | 0 | 是否虚拟用户 | 
 | 14 | is_refund | int4 |  |  |  |  | 0 | 是否退款 | 
 | 15 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 16 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_address_info
说明： 收件人地址信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | receiver_name | varchar |  |  |  |  |  | 收件人姓名 | 
 | 2 | detailed_address | varchar |  |  |  |  |  | 详细收货地址信息 | 
 | 3 | mobile | varchar |  |  |  |  |  | 收件人手机号码 | 
 | 4 | country | varchar |  |  |  |  |  | 国家 | 
 | 5 | province | varchar |  |  |  |  |  | 省份 | 
 | 6 | city | varchar |  |  |  |  |  | 城市 | 
 | 7 | town | varchar |  |  |  |  |  | 乡镇 | 
 | 8 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 9 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 10 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 11 | default | int4 |  |  |  |  | 0 | 是否默认收件地址。0否，1是 | 
 | 12 | status | int4 |  |  |  |  | 0 | 状态 | 
 | 13 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 14 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_area
说明： 省市区信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 名称 | 
 | 2 | parent_id | uuid |  |  |  | √ |  | 上级id | 
 | 3 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 4 | level | int4 |  |  |  |  | 0 | 层级 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_cart
说明： 购物车信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 关联user表id | 
 | 2 | minishop_spu_id | uuid |  |  |  |  |  | 关联minishop_spu表id | 
 | 3 | minishop_sku_id | uuid |  |  |  |  |  | 关联minishop_sku表id | 
 | 4 | product_id | uuid |  |  |  |  |  | 小商店内部商品ID | 
 | 5 | out_product_id | uuid |  |  |  |  |  | 商家自定义商品ID | 
 | 6 | sku_id | uuid |  |  |  |  |  | 小商店内部sku_iD | 
 | 7 | out_sku_id | uuid |  |  |  |  |  | 商家自定义sku_id | 
 | 8 | openid | varchar |  |  |  |  |  | 微信用户openid | 
 | 9 | appid | varchar |  |  |  |  |  | 应用appid | 
 | 10 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 11 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 12 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 13 | product_cnt | int4 |  |  |  |  | 1 | 商品数量 | 
 | 14 | status | int4 |  |  |  |  | 0 | 状态 | 
 | 15 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 16 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_config
说明： 商城配置
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 变量名 | 
 | 2 | group | varchar |  |  |  |  |  | 分组 | 
 | 3 | title | varchar |  |  |  |  |  | 变量标题 | 
 | 4 | tip | varchar |  |  |  |  |  | 变量描述 | 
 | 5 | type | varchar |  |  |  |  |  | 类型。string,text,int,bool,array,datetime,date,file | 
 | 6 | value | varchar |  |  |  |  |  | 变量值 | 
 | 7 | content | varchar |  |  |  | √ |  | 变量字典数据 | 
 | 8 | rule | varchar |  |  |  | √ |  | 验证规则 | 
 | 9 | extend | varchar |  |  |  | √ |  | 扩展属性 | 
 | 10 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 11 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 12 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 13 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 14 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_coupons
说明： 商城优惠券
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 名称 | 
 | 2 | type | varchar |  |  |  |  |  | 类型。cash=代金券,discount=折扣券 | 
 | 3 | goods_ids | varchar |  |  |  | √ |  | 适用商品 | 
 | 4 | description | varchar |  |  |  | √ |  | 描述 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | amount | float8 |  |  |  | √ | 0 | 券面额 | 
 | 7 | enough | float8 |  |  |  | √ | 0 | 消费门槛 | 
 | 8 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 9 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 10 | stock | int4 |  |  |  |  | 0 | 库存 | 
 | 11 | limit | int4 |  |  |  |  | 0 | 每人限制 | 
 | 12 | get_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 领取周期 | 
 | 13 | use_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 有效期 | 
 | 14 | use_time_start | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 开始使用时间 | 
 | 15 | use_time_end | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 结束使用时间 | 
 | 16 | get_time_start | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 开始领取时间 | 
 | 17 | get_time_end | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 结束领取时间 | 
 | 18 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 19 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_decorate
说明： 商城模板信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 模板名称 | 
 | 2 | type | varchar |  |  |  |  |  | 页面分类。shop=商城,custom=自定义,preview=临时预览 | 
 | 3 | image | varchar |  |  |  | √ |  | 图片 | 
 | 4 | memo | varchar |  |  |  | √ |  | 备注 | 
 | 5 | platform | varchar |  |  |  | √ |  | 适用平台。H5=H5,wxOfficialAccount=微信公众号网页,wxMiniProgram=微信小程序,App=App,preview=预览 | 
 | 6 | status | varchar |  |  |  | √ |  | 状态。normal,hidden | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 11 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_decorate_content
说明： 页面模板装修数据
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | type | varchar |  |  |  |  |  | 类型 | 
 | 2 | category | varchar |  |  |  |  |  | 页面类型。home=首页,user=个人中心,tabbar=底部导航,popup=弹出提醒,float-button=悬浮按钮,custom=自定义 | 
 | 3 | name | varchar |  |  |  |  |  | 名称 | 
 | 4 | content | varchar |  |  |  | √ |  | 内容。json数据 | 
 | 5 | decorate_id | uuid |  |  |  |  |  | 归属模板ID | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 11 | status | int4 |  |  |  |  | 1 | 状态。0隐藏，1显示 | 
 | 12 | weight | int4 |  |  |  |  | 0 | 排序 | 

#### 表名： minishop_dispatch
说明： 配送方式
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 名称 | 
 | 2 | type | varchar |  |  |  |  |  | 发货方式。express=物流快递,selfetch=用户自提,store=商户配送,autosend=自动发货 | 
 | 3 | type_ids | varchar |  |  |  | √ |  | 包含模板 | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_dispatch_autosend
说明： 自动发货
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | type | varchar |  |  |  |  |  | 自动发货类型。card=卡密,text=固定内容,params=自定义内容 | 
 | 2 | content | varchar |  |  |  |  |  | 发货内容 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_dispatch_express
说明： 发货信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | type | varchar |  |  |  |  |  | 计费方式。number=件数,weight=重量 | 
 | 2 | province_ids | uuid |  |  |  | √ |  | 省份 | 
 | 3 | city_ids | uuid |  |  |  | √ |  | 市级 | 
 | 4 | area_ids | uuid |  |  |  | √ |  | 区域 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | weigh | int4 |  |  |  | √ | 0 | 权重 | 
 | 9 | first_num | int4 |  |  |  |  | 0 | 首(重 件)数 | 
 | 10 | first_price | float8 |  |  |  | √ | 0 | 首(重 件) | 
 | 11 | additional_num | int4 |  |  |  |  | 0 | 续(重 件)数 | 
 | 12 | additional_price | float8 |  |  |  |  | 0 | 续(重 件) | 
 | 13 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 14 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_dispatch_selfetch
说明： 自提数据
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | store_ids | uuid |  |  |  |  |  | 包含门店 | 
 | 2 | expire_type | varchar |  |  |  |  |  | 过期类型。day=天数,time=截至日期 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | expire_day | int4 |  |  |  |  | 0 | X天过期 | 
 | 7 | expire_time | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 截至日期 | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_dispatch_store
说明： 自提店铺
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 名称 | 
 | 2 | store_ids | varchar |  |  |  |  |  | 包含门店 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_express
说明： 快递公司
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 快递公司名 | 
 | 2 | code | varchar |  |  |  |  |  | 编码 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | weigh | int4 |  |  |  |  | 0 | 权重 | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_failed_job
说明： 事务失败数据
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | data | varchar |  |  |  |  |  | 数据 | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 6 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_goods_comment
说明： 商品评论
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | goods_id | uuid |  |  |  |  |  | 商品id | 
 | 2 | order_id | uuid |  |  |  |  |  | 订单id | 
 | 3 | order_item_id | uuid |  |  |  |  |  | 订单商品 | 
 | 4 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 5 | content | varchar |  |  |  | √ |  | 评价内容 | 
 | 6 | images | varchar |  |  |  | √ |  | 评价图片 | 
 | 7 | reply_content | varchar |  |  |  | √ |  | 显示状态 | 
 | 8 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 9 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 10 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 11 | level | int4 |  |  |  |  | 0 | 评价星级 | 
 | 12 | reply_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 回复时间 | 
 | 13 | status | int4 |  |  |  |  | 0 | 显示状态 | 
 | 14 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 15 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_goods_service
说明： 商品服务标识
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 名称 | 
 | 2 | image | varchar |  |  |  | √ |  | 服务标志 | 
 | 3 | description | varchar |  |  |  |  |  | 描述 | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_link
说明： 商城链接
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  | √ |  | 名称 | 
 | 2 | path | varchar |  |  |  | √ |  | 路径 | 
 | 3 | group | varchar |  |  |  | √ |  | 所属分组 | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_order
说明： 商城订单
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | order_id | varchar |  |  |  | √ |  | 微信侧订单id | 
 | 2 | out_order_id | varchar |  |  |  |  |  | 商家自定义订单ID | 
 | 3 | out_trade_no | varchar |  |  |  | √ |  | 商户支付订单号 | 
 | 4 | openid | varchar |  |  |  |  |  | 微信用户openid | 
 | 5 | user_id | varchar |  |  |  | √ |  | 用户id | 
 | 6 | path | varchar |  |  |  | √ |  | 商家小程序该订单的页面path，用于微信侧订单中心跳转 | 
 | 7 | order_detail_id | varchar |  |  |  | √ |  | 关联order_detail表id | 
 | 8 | address_info_id | varchar |  |  |  | √ |  | 关联minishop_user_address表id | 
 | 9 | out_aftersale_id | varchar |  |  |  | √ |  | 售后ID | 
 | 10 | ticket | varchar |  |  |  | √ |  | 拉起收银台的ticket | 
 | 11 | ext_json | varchar |  |  |  | √ |  | 附加信息 | 
 | 12 | platform | varchar |  |  |  |  |  | 平台。H5=H5,wxOfficialAccount=微信公众号,wxMiniProgram=微信小程序,App=App | 
 | 13 | transaction_id | varchar |  |  |  | √ |  | 支付流水号 | 
 | 14 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 15 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 16 | appid | varchar |  |  |  | √ |  |  | 
 | 17 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 18 | type | int4 |  |  |  |  | 0 | 非必填，默认为0。0 普通场景, 1 合单支付 | 
 | 19 | scene | int4 |  |  |  | √ | 0 | 下单时小程序的场景值 | 
 | 20 | ticket_expire_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | ticket有效截止时间 | 
 | 21 | final_price | int4 |  |  |  | √ | 0 | 订单最终价格（单位：分） | 
 | 22 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 23 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 24 | status | int4 |  |  |  |  | 0 | 订单状态。10=待付款,11=收银台支付完成（自动流转，对商家来说和10同等对待即可）,20=待发货,30=待收货,100=完成,200=全部商品售后之后，订单取消,250=用户主动取消 待付款超时取消 商家取消 | 

#### 表名： minishop_order_action
说明： 订单操作数据
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | order_id | uuid |  |  |  |  |  | 微信侧订单id | 
 | 2 | out_order_id | varchar |  |  |  |  |  | 商家自定义订单ID | 
 | 3 | order_item_id | uuid |  |  |  | √ |  | 订单商品id | 
 | 4 | oper_type | varchar |  |  |  |  |  | 操作人类型 user,store,admin,system | 
 | 5 | oper_id | uuid |  |  |  | √ |  | 操作人id。关联user表id | 
 | 6 | remark | varchar |  |  |  | √ |  | 操作备注 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | order_status | int4 |  |  |  |  | 0 | 订单状态 | 
 | 11 | dispatch_status | int4 |  |  |  |  | 0 | 发货状态 | 
 | 12 | comment_status | int4 |  |  |  |  | 0 | 评论状态 | 
 | 13 | aftersale_status | int4 |  |  |  |  | 0 | 售后状态 | 
 | 14 | refund_status | int4 |  |  |  |  | 0 | 退款状态 | 
 | 15 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 16 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_order_aftersale
说明： 订单售后记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | aftersale_sn | uuid |  |  |  |  |  | 售后单号 | 
 | 2 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 3 | phone | varchar |  |  |  | √ |  | 联系方式 | 
 | 4 | activity_id | varchar |  |  |  | √ |  | 活动 | 
 | 5 | activity_type | varchar |  |  |  | √ |  | 活动类型 | 
 | 6 | order_id | varchar |  |  |  |  |  | 微信侧订单id | 
 | 7 | out_order_id | varchar |  |  |  | √ |  | 商家自定义订单ID | 
 | 8 | order_item_id | uuid |  |  |  |  |  | 订单商品 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | type | int4 |  |  |  |  | 0 | 类型。1=退款,2=退货,3=其他 | 
 | 11 | goods_id | uuid |  |  |  |  |  | 商品id | 
 | 12 | goods_sku_price_id | uuid |  |  |  |  |  | 规格id | 
 | 13 | goods_sku_text | varchar |  |  |  | √ |  | 规格名 | 
 | 14 | goods_title | varchar |  |  |  | √ |  | 商品名称 | 
 | 15 | goods_image | varchar |  |  |  | √ |  | 商品图片 | 
 | 16 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 17 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 18 | goods_original_price | float8 |  |  |  |  | 0 | 商品原价 | 
 | 19 | discount_fee | float8 |  |  |  | √ | 0 | 优惠费用 | 
 | 20 | goods_price | float8 |  |  |  |  | 0 | 商品价格 | 
 | 21 | goods_num | int4 |  |  |  |  | 0 | 购买数量 | 
 | 22 | dispatch_status | int4 |  |  |  |  | 0 | 发货状态。0=未发货,1=已发货,2=已收货 | 
 | 23 | dispatch_fee | float8 |  |  |  | √ | 0 | 发货费用 | 
 | 24 | aftersale_status | int4 |  |  |  |  | 0 | 售后状态。-1=拒绝,0=未处理,1=处理中,2=售后完成 | 
 | 25 | refund_status | int4 |  |  |  |  | 0 | 退款状态。-1=拒绝退款,0=未退款,1=同意 | 
 | 26 | refund_fee | float8 |  |  |  | √ | 0 | 退款金额 | 
 | 27 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 28 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_order_aftersale_log
说明： 订单售后记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | order_id | varchar |  |  |  |  |  | 微信侧订单id | 
 | 2 | out_order_id | varchar |  |  |  | √ |  | 商家自定义订单ID | 
 | 3 | order_aftersale_id | uuid |  |  |  |  |  | 售后单 | 
 | 4 | oper_type | varchar |  |  |  |  |  | 操作人类型。user,store,admin,system | 
 | 5 | oper_id | uuid |  |  |  |  |  | 操作人id | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | dispatch_status | int4 |  |  |  |  | 0 | 发货状态 | 
 | 8 | aftersale_status | int4 |  |  |  |  | 0 | 售后状态 | 
 | 9 | reason | varchar |  |  |  | √ |  | 售后原因 | 
 | 10 | content | varchar |  |  |  | √ |  | 内容 | 
 | 11 | images | varchar |  |  |  | √ |  | 图片 | 
 | 12 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 13 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 14 | refund_status | int4 |  |  |  |  | 0 | 退款状态 | 
 | 15 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 16 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_order_detail
说明： 订单详情。数据结构与此文档一致 (https   developers.weixin.qq.com miniprogram dev platform-capabilities business-capabilities ministore minishopopencomponent API order get_order_detail.html)
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | product_infos | varchar |  |  |  |  |  | 订单商品信息 | 
 | 2 | pay_info | varchar |  |  |  | √ |  | 订单支付信息。payorder时action_type!=6时存在 | 
 | 3 | multi_pay_info | varchar |  |  |  | √ |  | 订单支付信息。payorder时action_type=6时存在 | 
 | 4 | price_info | varchar |  |  |  | √ |  | 订单价格信息 | 
 | 5 | delivery_detail | varchar |  |  |  | √ |  | 订单物流信息。必须调过发货接口才会存在这个字段 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | status | int4 |  |  |  |  | 0 | 订单详情状态 | 
 | 10 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 11 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_order_express
说明： 订单快递信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | order_id | uuid |  |  |  |  |  | 订单id | 
 | 3 | express_name | varchar |  |  |  |  |  | 快递公司 | 
 | 4 | express_code | varchar |  |  |  |  |  | 公司编号 | 
 | 5 | express_no | varchar |  |  |  |  |  | 快递单号 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_order_express_log
说明： 订单快递记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | order_id | uuid |  |  |  |  |  | 订单id | 
 | 3 | order_express_id | uuid |  |  |  |  |  | 包裹快递单号 | 
 | 4 | location | varchar |  |  |  | √ |  | 地址信息 | 
 | 5 | content | varchar |  |  |  | √ |  | 物流信息 | 
 | 6 | changedate | varchar |  |  |  | √ |  | 变动时间 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | status | int4 |  |  |  |  | 0 | 物流状态 | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_order_item
说明： 订单详情
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | order_id | varchar |  |  |  | √ |  | 微信侧订单id | 
 | 3 | out_order_id | varchar |  |  |  |  |  | 商家自定义订单ID | 
 | 4 | goods_id | uuid |  |  |  |  |  | 商品id | 
 | 5 | goods_type | varchar |  |  |  |  |  | 商品类型。normal=实体商品,virtual=虚拟商品 | 
 | 6 | goods_sku_price_id | uuid |  |  |  |  |  | 规格id | 
 | 7 | activity_id | uuid |  |  |  | √ |  | 活动id | 
 | 8 | activity_type | varchar |  |  |  | √ |  | 活动类型 | 
 | 9 | item_goods_sku_price_id | uuid |  |  |  | √ |  | 活动规格 积分商城规格id | 
 | 10 | goods_sku_text | varchar |  |  |  | √ |  | 规格名 | 
 | 11 | goods_title | varchar |  |  |  | √ |  | 商品名称 | 
 | 12 | goods_image | varchar |  |  |  | √ |  | 商品图片 | 
 | 13 | dispatch_type | varchar |  |  |  | √ |  | 发货方式 | 
 | 14 | dispatch_id | uuid |  |  |  | √ |  | 发货模板 | 
 | 15 | store_id | uuid |  |  |  | √ |  | 门店 | 
 | 16 | refund_msg | varchar |  |  |  | √ |  | 退款原因 | 
 | 17 | express_name | varchar |  |  |  | √ |  | 快递公司 | 
 | 18 | express_code | varchar |  |  |  | √ |  | 快递公司编号 | 
 | 19 | express_no | varchar |  |  |  | √ |  | 快递单号 | 
 | 20 | ext | varchar |  |  |  | √ |  | 附加字段 | 
 | 21 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 22 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 23 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 24 | goods_original_price | float8 |  |  |  | √ | 0 | 商品原价 | 
 | 25 | discount_fee | float8 |  |  |  | √ | 0 | 优惠费用 | 
 | 26 | goods_price | float8 |  |  |  | √ | 0 | 商品价格 | 
 | 27 | goods_num | int4 |  |  |  |  | 0 | 购买数量 | 
 | 28 | pay_price | float8 |  |  |  |  | 0 | 支付金额(不含运费) | 
 | 29 | dispatch_status | int4 |  |  |  |  | 0 | 发货状态。0=未发货,1=已发货,2=已收货 | 
 | 30 | dispatch_fee | float8 |  |  |  | √ | 0 | 发货费用 | 
 | 31 | aftersale_status | int4 |  |  |  |  | 0 | 售后状态。-1=拒绝,0=未申请,1=申请售后,2=售后完成 | 
 | 32 | comment_status | int4 |  |  |  |  | 0 | 评价状态。0=未评价,1=已评价 | 
 | 33 | refund_status | int4 |  |  |  | √ | 0 | 退款状态。-1=拒绝退款,0=无,1=申请中,2=同意 | 
 | 34 | refund_fee | float8 |  |  |  | √ | 0 | 退款金额 | 
 | 35 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 36 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_order_status
说明： 订单状态枚举
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 描述 | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | value | int4 |  |  |  |  | 0 | 枚举值 | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_product_category
说明： 商品类目
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | parent_id | uuid |  |  |  | √ |  | 类目父ID | 
 | 2 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 3 | name | varchar |  |  |  |  |  | 类目名称 | 
 | 4 | category_title | varchar |  |  |  |  |  | 类目标题 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | category_image | varchar |  |  |  | √ |  | 类目图片 | 
 | 8 | category_type | varchar |  |  |  | √ |  | 类目类型 | 
 | 9 | weight | int4 |  |  |  |  | 0 | 类目排序 | 
 | 10 | status | int4 |  |  |  |  | 0 | 类目状态 | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_refund_log
说明： 退款记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | order_id | varchar |  |  |  |  |  | 微信侧订单id | 
 | 2 | out_order_id | varchar |  |  |  |  |  | 商家自定义订单ID | 
 | 3 | refund_sn | varchar |  |  |  |  |  | 商户退款单号 | 
 | 4 | order_item_id | varchar |  |  |  |  |  | 订单商品 | 
 | 5 | pay_type | varchar |  |  |  |  |  | 付款方式 | 
 | 6 | payment_json | varchar |  |  |  | √ |  | 退款原始数据 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | pay_fee | float8 |  |  |  |  | 0 | 支付金额 | 
 | 11 | refund_fee | float8 |  |  |  |  | 0 | 退款金额 | 
 | 12 | status | int4 |  |  |  |  | 0 | 退款状态。0=退款中,1=退款完成,-1=退款失败' | 
 | 13 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 14 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_share
说明： 分享记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | share_id | uuid |  |  |  |  |  | 分享人 | 
 | 3 | type | varchar |  |  |  | √ |  | 识别类型 | 
 | 4 | type_id | varchar |  |  |  | √ |  | 识别标识 | 
 | 5 | platform | varchar |  |  |  | √ |  | 平台 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_shipping_method
说明： 发货方式枚举
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 描述 | 
 | 2 | value | varchar |  |  |  |  |  | 枚举值 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_sku
说明： sku数据。与此文档数据结构一致(https   developers.weixin.qq.com miniprogram dev platform-capabilities business-capabilities ministore minishopopencomponent API sku get_sku.html)
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | product_id | uuid |  |  |  |  |  | 小商店内部商品ID | 
 | 2 | out_product_id | varchar |  |  |  |  |  | 商家自定义商品ID | 
 | 3 | sku_id | uuid |  |  |  |  |  | 小商店内部sku_iD | 
 | 4 | sku_name | varchar |  |  |  | √ |  | sku名称 | 
 | 5 | out_sku_id | varchar |  |  |  |  |  | 商家自定义sku_id | 
 | 6 | thumb_img | varchar |  |  |  |  |  | sku小图 | 
 | 7 | barcode | varchar |  |  |  |  |  | 条形码 | 
 | 8 | sku_code | varchar |  |  |  |  |  | 商品编码 | 
 | 9 | sku_attrs | uuid |  |  |  |  |  | 属性自定义用 | 
 | 10 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 11 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 12 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 13 | sale_price | int4 |  |  |  |  | 0 | 售卖价格,以分为单位 | 
 | 14 | market_price | int4 |  |  |  |  | 0 | 市场价格,以分为单位 | 
 | 15 | stock_num | int4 |  |  |  |  | 0 | 库存 | 
 | 16 | status | int4 |  |  |  |  | 0 | sku状态。5=上架中,21=假删除 | 
 | 17 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 18 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_sku_attrs
说明： sku属性
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 名称 | 
 | 2 | key | varchar |  |  |  | √ |  | 属性键 | 
 | 3 | value | varchar |  |  |  | √ |  | 属性值 | 
 | 4 | parent_id | uuid |  |  |  | √ |  | 父属性组 | 
 | 5 | spu_id | uuid |  |  |  |  |  | 所属商品id。关联spu表out_product_d | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | weigh | int4 |  |  |  |  | 0 | 排序 | 
 | 10 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 11 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_sku_status
说明： sku状态
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 描述 | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | value | int4 |  |  |  |  | 0 | 枚举值 | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_spu
说明： spu数据。与此文档一致(https   developers.weixin.qq.com miniprogram dev platform-capabilities business-capabilities ministore minishopopencomponent API spu get_spu.html)
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | out_product_id | varchar |  |  |  | √ |  | 商家自定义商品ID | 
 | 2 | title | varchar |  |  |  |  |  | 标题 | 
 | 3 | subtitle | varchar |  |  |  | √ |  | 副标题 | 
 | 4 | headimg | varchar |  |  |  |  |  | 主图,多张,列表 | 
 | 5 | cats | varchar |  |  |  | √ |  | 商家需要先申请可使用类目 | 
 | 6 | attrs | varchar |  |  |  | √ |  | 商品属性 | 
 | 7 | model | uuid |  |  |  | √ |  | 商品型号 | 
 | 8 | dispatch_type | varchar |  |  |  | √ |  | 发货方式。express=物流快递,selfetch=用户自提,store=商家配送,autosend=自动发货 | 
 | 9 | express_info | varchar |  |  |  | √ |  | 运费模板ID | 
 | 10 | shopcat | varchar |  |  |  | √ |  | 分类ID | 
 | 11 | skus | varchar |  |  |  | √ |  | 商品skus | 
 | 12 | template_id | varchar |  |  |  | √ |  | 模板id | 
 | 13 | ext_json | varchar |  |  |  | √ |  | ext_json | 
 | 14 | memo | varchar |  |  |  | √ |  | 备注 | 
 | 15 | ext_attrs | varchar |  |  |  | √ |  | 更多属性 | 
 | 16 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 17 | address | varchar |  |  |  | √ |  |  | 
 | 18 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 19 | desc_info | varchar |  |  |  | √ |  | 商品详情，图文 | 
 | 20 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 21 | status | int4 |  |  |  |  | 0 | 商品线上状态 | 
 | 22 | edit_status | int4 |  |  |  |  | 0 | 商品草稿状态 | 
 | 23 | min_price | int4 |  |  |  |  | 0 | 商品SKU最小价格（单位：分） | 
 | 24 | sales_count | int4 |  |  |  |  | 0 | 销量 | 
 | 25 | weigh | int4 |  |  |  |  | 0 | 排序 | 
 | 26 | start_at | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP |  | 
 | 27 | end_at | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP |  | 
 | 28 | meet_at | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP |  | 
 | 29 | latitude | float8 |  |  |  | √ | 0 |  | 
 | 30 | longitude | float8 |  |  |  | √ | 0 |  | 
 | 31 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 32 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 33 | brand_id | int4 |  |  |  | √ | 0 |  | 

#### 表名： minishop_spu_edit_status
说明： spu编辑状态枚举
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 描述 | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | value | int4 |  |  |  |  | 0 | 枚举值 | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_spu_status
说明： spu状态枚举
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 描述 | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | value | int4 |  |  |  |  | 0 | 枚举值 | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_store
说明： 门店信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 门店名称 | 
 | 2 | headimg | varchar |  |  |  |  |  |  | 
 | 3 | realname | varchar |  |  |  | √ |  | 联系人 | 
 | 4 | phone | varchar |  |  |  | √ |  | 联系电话 | 
 | 5 | province_name | varchar |  |  |  |  |  | 省 | 
 | 6 | city_name | varchar |  |  |  |  |  | 市 | 
 | 7 | area_name | varchar |  |  |  |  |  | 区 | 
 | 8 | province_id | uuid |  |  |  | √ |  | 省id | 
 | 9 | city_id | uuid |  |  |  | √ |  | 市id | 
 | 10 | area_id | uuid |  |  |  | √ |  | 区id | 
 | 11 | address | varchar |  |  |  |  |  | 详细地址 | 
 | 12 | service_type | varchar |  |  |  | √ |  | 服务范围 | 
 | 13 | service_province_ids | varchar |  |  |  | √ |  | 服务行政省 | 
 | 14 | service_city_ids | uuid |  |  |  | √ |  | 服务行政市 | 
 | 15 | service_area_ids | varchar |  |  |  | √ |  | 服务行政区 | 
 | 16 | openhours | varchar |  |  |  | √ |  | 营业时间 | 
 | 17 | openweeks | varchar |  |  |  | √ |  | 营业天数 | 
 | 18 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 19 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 20 | desc_info | varchar |  |  |  | √ |  |  | 
 | 21 | parent_id | uuid |  |  |  | √ |  |  | 
 | 22 | principal | varchar |  |  |  | √ |  |  | 
 | 23 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 24 | latitude | float8 |  |  |  | √ | 0 | 纬度 | 
 | 25 | longitude | float8 |  |  |  | √ | 0 | 经度 | 
 | 26 | store | int4 |  |  |  |  | 0 | 支持配送。0=否,1=是 | 
 | 27 | selfetch | int4 |  |  |  |  | 0 | 支持自提。0=否,1=是 | 
 | 28 | service_radius | int4 |  |  |  |  | 0 | 服务半径 | 
 | 29 | status | int4 |  |  |  |  | 0 | 门店状态。0=禁用,1=启用 | 
 | 30 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 31 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_store_apply
说明： 门店申请
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  | √ |  | 用户id | 
 | 2 | status_msg | varchar |  |  |  | √ |  | 审核状态。-1驳回,0=未审核,1=已通过 | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | apply_num | int4 |  |  |  | √ | 0 | 申请次数 | 
 | 7 | status | int4 |  |  |  | √ | 0 | 审核信息 | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 10 | gender | varchar |  |  |  | √ | ''::character varying |  | 
 | 11 | idcard_image | varchar |  |  |  | √ | ''::character varying |  | 
 | 12 | idcard_no | varchar |  |  |  | √ | ''::character varying |  | 
 | 13 | mobile | varchar |  |  |  | √ | ''::character varying |  | 
 | 14 | realname | varchar |  |  |  | √ | ''::character varying |  | 
 | 15 | skill | varchar |  |  |  | √ | ''::character varying |  | 
 | 16 | user_model | varchar |  |  |  | √ | ''::character varying |  | 
 | 17 | address | varchar |  |  |  | √ | ''::character varying |  | 
 | 18 | age | varchar |  |  |  | √ | ''::character varying |  | 
 | 19 | badly_off | varchar |  |  |  | √ | ''::character varying |  | 
 | 20 | birthday | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP |  | 
 | 21 | buddhist_name | varchar |  |  |  | √ | ''::character varying |  | 
 | 22 | career | varchar |  |  |  | √ | ''::character varying |  | 
 | 23 | conversion_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP |  | 
 | 24 | corporation | varchar |  |  |  | √ | ''::character varying |  | 
 | 25 | education | varchar |  |  |  | √ | ''::character varying |  | 
 | 26 | emergency_contact | varchar |  |  |  | √ | ''::character varying |  | 
 | 27 | emergency_mobile | varchar |  |  |  | √ | ''::character varying |  | 
 | 28 | emergency_relationship | varchar |  |  |  | √ | ''::character varying |  | 
 | 29 | health | varchar |  |  |  | √ | ''::character varying |  | 
 | 30 | idcard_type | varchar |  |  |  | √ | ''::character varying |  | 
 | 31 | job_title | varchar |  |  |  | √ | ''::character varying |  | 
 | 32 | nationality | varchar |  |  |  | √ | ''::character varying |  | 
 | 33 | reason | varchar |  |  |  | √ | ''::character varying |  | 
 | 34 | school | varchar |  |  |  | √ | ''::character varying |  | 
 | 35 | signin_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP |  | 
 | 36 | signout_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP |  | 

#### 表名： minishop_user_address
说明： 用户收获地址
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | consignee | varchar |  |  |  | √ |  | 收货人 | 
 | 3 | phone | varchar |  |  |  | √ |  | 联系电话 | 
 | 4 | province_name | varchar |  |  |  | √ |  | 省 | 
 | 5 | city_name | varchar |  |  |  | √ |  | 市 | 
 | 6 | area_name | varchar |  |  |  | √ |  | 区 | 
 | 7 | province_id | uuid |  |  |  | √ |  | 省id | 
 | 8 | city_id | uuid |  |  |  | √ |  | 市id | 
 | 9 | area_id | uuid |  |  |  | √ |  | 区id | 
 | 10 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 11 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 12 | address | varchar |  |  |  | √ |  | 详细地址 | 
 | 13 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 14 | is_default | int4 |  |  |  |  | 0 | 是否默认。0否，1是 | 
 | 15 | latitude | float8 |  |  |  | √ | 0 | 纬度 | 
 | 16 | longitude | float8 |  |  |  | √ | 0 | 经度 | 
 | 17 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 18 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_user_bank
说明： 用户银行账户
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | realname | varchar |  |  |  | √ |  | 真实姓名 | 
 | 3 | bank_name | varchar |  |  |  | √ |  | 银行名 | 
 | 4 | card_no | varchar |  |  |  | √ |  | 卡号 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | is_default | int4 |  |  |  |  | 0 | 是否默认。0否。1是 | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_user_coupons
说明： 用户优惠券
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | coupons_id | uuid |  |  |  |  |  | 优惠券id | 
 | 3 | use_order_id | uuid |  |  |  |  |  | 订单id | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | use_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 使用时间 | 
 | 8 | create_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 领取时间 | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_user_favorite
说明： 用户收藏
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | goods_id | uuid |  |  |  |  |  | 商品id | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： minishop_user_store
说明： 用户所属门店
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | store_id | uuid |  |  |  |  |  | 门店id | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： module_config
说明： 模块配置信息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | module_name | varchar |  |  |  |  |  | 模块唯一名。与模块module.json中uni_name一致 | 
 | 2 | name | varchar |  |  |  |  |  | 配置名称 | 
 | 3 | component | varchar |  |  |  | √ |  | tab 引入的组件名称 | 
 | 4 | key | varchar |  |  |  |  |  | 配置键名 | 
 | 5 | value | varchar |  |  |  | √ |  | 配置键值 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | parent_id | uuid |  |  |  | √ |  |  | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | status | int4 |  |  |  |  | 0 | 状态。1=启用,2=禁用 | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： operate_log
说明： 操作记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | module | varchar |  |  |  |  |  | 模块名称 | 
 | 2 | operate | varchar |  |  |  |  |  | 操作模块 | 
 | 3 | route | varchar |  |  |  |  |  | 路由 | 
 | 4 | params | varchar |  |  |  |  |  | 参数 | 
 | 5 | ip | varchar |  |  |  |  |  | ip | 
 | 6 | method | varchar |  |  |  |  |  | 请求方法 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 11 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： os_platform
说明： 操作系统
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 描述 | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | value | int4 |  |  |  |  | 0 | 枚举值 | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： permissions
说明： 权限
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | permission_name | varchar |  |  |  |  |  | 菜单名称。type=3时遵循uctoo v4路由规则。type=1并且是数据库菜单时，遵循database.数据库名.表名规则。其他菜单时暂无规律，可新制定规则，例如以menu.开头。type=2时，暂无规律，可新制定规则，例如以button.开头 | 
 | 2 | level | varchar |  |  |  | √ |  | 层级。顶层为0 | 
 | 3 | icon | varchar |  |  |  | √ |  | 菜单图标 | 
 | 4 | module | varchar |  |  |  | √ |  | 模块 | 
 | 5 | component | varchar |  |  |  | √ |  | 组件名称，对应前端项目组件路径地址 | 
 | 6 | redirect | varchar |  |  |  | √ |  | 跳转地址 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | type | int4 |  |  |  |  | 1 | 类型。1 菜单 2 按钮 3 api| 
 | 11 | hidden | int4 |  |  |  |  | 1 | 是否隐藏。0隐藏，1显示 | 
 | 12 | weight | int4 |  |  |  |  | 0 | 排序 | 
 | 13 | path | varchar |  |  |  |  |  | 对应url地址 | 
 | 14 | title | varchar |  |  |  | √ |  |  | 
 | 15 | parent_id | uuid |  |  |  | √ |  | 父权限节点id。type=3的数据库菜单都在permission_name=Database的节点下 | 
 | 
 | 16 | meta | jsonb |  |  |  | √ |  |  | 
 | 17 | method | varchar |  |  |  | √ |  | type=3时，api请求方法，GET、POST | 
 | 
 | 18 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 19 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 20 | keepalive | int4 |  |  |  |  | 1 | 1 缓存 2 不存在 | 

#### 表名： review
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | score | int4 |  |  |  |  |  |  | 
 | 2 | description | varchar |  |  |  |  |  |  | 
 | 3 | creator_name | varchar |  |  |  |  |  |  | 
 | 4 | group_id | uuid |  |  |  | √ |  |  | 
 | 5 | link | uuid |  |  |  | √ |  |  | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： sensitive_word
说明： 敏感词
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | word | varchar |  |  |  |  |  | 词汇 | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 6 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： sms_config
说明： 短信配置
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  | √ |  | 运营商名称 | 
 | 2 | parent_id | uuid |  |  |  | √ |  | 父级id | 
 | 3 | key | varchar |  |  |  |  |  | key | 
 | 4 | value | varchar |  |  |  |  |  | value | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： sms_log
说明： 短信记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | event | varchar |  |  |  |  |  | 事件 | 
 | 2 | mobile | varchar |  |  |  |  |  | 手机号 | 
 | 3 | code | varchar |  |  |  |  |  | 验证码 | 
 | 4 | ip | varchar |  |  |  | √ |  | ip | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | times | int4 |  |  |  |  | 0 | 验证次数 | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： sms_template
说明： 短信模板
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 模版名称 | 
 | 2 | operator | varchar |  |  |  |  |  | 运营商 | 
 | 3 | identify | varchar |  |  |  |  |  | 模版标识 | 
 | 4 | code | varchar |  |  |  |  |  | 模版CODE | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： tag
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  |  | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 6 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： uctoo_role
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  |  | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 6 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： uctoo_session
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  |  | 
 | 2 | user_agent | varchar |  |  |  | √ |  |  | 
 | 3 | ip | varchar |  |  |  |  |  |  | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | valid | bool |  |  |  |  | true |  | 
 | 7 | created_at | date |  |  |  |  | CURRENT_DATE | 创建时间 | 
 | 8 | updated_at | date |  |  |  |  | CURRENT_DATE | 更新时间 | 
 | 9 | auth_provider | int4 |  |  |  |  | 0 |  | 
 | 10 | id | uuid |  | √ |  |  | gen_random_uuid |  | 

#### 表名： uctoo_user
说明： 用户表。相当于account。RBAC中的用户
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | access_token | varchar |  |  |  | √ |  |  | 
 | 2 | name | varchar |  |  |  |  |  | 姓名 | 
 | 3 | username | varchar |  |  |  |  |  | 登录帐号 | 
 | 4 | email | varchar |  |  |  |  |  | 登录email | 
 | 5 | password | varchar |  |  |  |  |  | 密码 | 
 | 6 | avatar | varchar |  |  |  | √ |  | 头像 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | last_login_ip | varchar |  |  |  | √ |  | 最近一次登录ip | 
 | 10 | remember_token | varchar |  |  |  | √ |  | 是否记录token。用于再次自动登录 | 
 | 11 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 13 | last_login | date |  |  |  |  | CURRENT_DATE | 最近一次登录时间 | 
 | 14 | auth_provider | int4 |  |  |  |  | 0 | 认证提供商 | 
 | 15 | last_login_time | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 最近一次登录时间 | 
 | 16 | status | int4 |  |  |  |  | 0 |  | 
 | 17 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： unipay_applets
说明： 统一支付应用
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 应用名称 | 
 | 2 | operator | varchar |  |  |  |  |  | 运营商 | 
 | 3 | appid | varchar |  |  |  |  |  | appid | 
 | 4 | code | varchar |  |  |  |  |  | 应用CODE | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： unipay_config
说明： 统一支付配置
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  | √ |  | 运营商名称 | 
 | 2 | appid | varchar |  |  |  |  |  |  | 
 | 3 | operator | varchar |  |  |  |  |  |  | 
 | 4 | key | varchar |  |  |  |  |  | key | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | value | varchar |  |  |  |  |  | value | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 10 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_group
说明： 用户组
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | group_name | varchar |  |  |  |  |  | 组名 | 
 | 2 | parent_id | varchar |  |  |  | √ |  | 父级id | 
 | 3 | code | varchar |  |  |  |  |  | 组标识 | 
 | 4 | intro | varchar |  |  |  | √ |  | 组介绍 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_has_account
说明： 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  |  | 
 | 2 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 3 | account_type | varchar |  |  |  | √ |  |  | 
 | 4 | account_id | uuid |  |  |  |  |  |  | 
 | 5 | creator | uuid |  |  |  | √ |  |  | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  |  | 
 | 7 | status | int4 |  |  |  |  | 1 |  | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP |  | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP |  | 

#### 表名： user_has_group
说明： 用户与组关联
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | groupable_id | uuid |  |  |  |  |  | 可分组数据id。 | 
 | 2 | groupable_type | varchar |  |  |  | √ |  | 可分组数据类型。与表名一致 | 
 | 3 | group_id | uuid |  |  |  |  |  | 组id | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | status | int4 |  |  |  |  | 0 |  | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_has_jobs
说明： 用户与职位关联
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  |  | 
 | 2 | job_id | uuid |  |  |  |  |  |  | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | status | int4 |  |  |  |  | 0 |  | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_has_roles
说明： 用户与角色关联
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  |  | 
 | 2 | role_id | uuid |  |  |  |  |  |  | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | status | int4 |  |  |  |  | 0 |  | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_messages
说明： 用户消息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | ai_task_id | uuid |  |  |  |  |  | AI系统任务id | 
 | 2 | from_uid | uuid |  |  |  |  |  | 发消息用户id | 
 | 3 | from_model | varchar |  |  |  |  |  | 发消息用户表名 | 
 | 4 | from_ai_user_id | uuid |  |  |  | √ |  | 发消息AI系统用户id | 
 | 5 | to_user_id | uuid |  |  |  |  |  | 收消息用户id | 
 | 6 | to_model | uuid |  |  |  |  |  | 收消息用户表名 | 
 | 7 | to_ai_user_id | uuid |  |  |  | √ |  |  | 
 | 8 | msg_type | varchar |  |  |  |  |  | 消息类型 | 
 | 9 | msg_content | varchar |  |  |  |  |  | 消息内容 | 
 | 10 | ext | varchar |  |  |  | √ |  | 扩展信息 | 
 | 11 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 12 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 13 | status | int4 |  |  |  |  | 0 | 消息状态 | 
 | 14 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 15 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 16 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_role
说明： 用户与角色关联
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  |  | 
 | 2 | role_id | uuid |  |  |  |  |  |  | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_score
说明： 用户积分
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | appid | varchar |  |  |  | √ |  | appid | 
 | 3 | from_umodel | varchar |  |  |  |  |  | 用户表 | 
 | 4 | ext_score | varchar |  |  |  | √ |  | 更多积分 | 
 | 5 | medals | varchar |  |  |  | √ |  | 奖牌 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | total_score | int4 |  |  |  |  | 0 | 总分 | 
 | 8 | team_score | int4 |  |  |  |  | 0 | 团队积分 | 
 | 9 | volunteer_score | int4 |  |  |  |  | 0 | 志愿者积分 | 
 | 10 | event_score | int4 |  |  |  |  | 0 | 活动积分 | 
 | 11 | ext_info | varchar |  |  |  | √ |  | 更多信息 | 
 | 12 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 13 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 14 | total_times | int4 |  |  |  | √ | 0 | 总次数 | 
 | 15 | total_medals | int4 |  |  |  | √ | 0 | 总徽章数 | 
 | 16 | annual_times | int4 |  |  |  | √ | 0 | 年次数 | 
 | 17 | annual_medals | int4 |  |  |  | √ | 0 | 年徽章数 | 
 | 18 | monthly_times | int4 |  |  |  | √ | 0 | 月次数 | 
 | 19 | monthly_medals | int4 |  |  |  | √ | 0 | 月徽章数 | 
 | 20 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 21 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_sign
说明： 打卡
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | appid | varchar |  |  |  | √ |  | appid | 
 | 3 | from_umodel | varchar |  |  |  |  |  | 签到用户表 | 
 | 4 | to_id | varchar |  |  |  | √ |  | 打卡数据id | 
 | 5 | to_model | varchar |  |  |  | √ |  | 打卡数据表 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | sign_at | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 签到日期 | 
 | 10 | score | int4 |  |  |  |  | 0 | 所得积分 | 
 | 11 | is_replenish | int4 |  |  |  | √ | 0 | 是否补签。0=正常,1=补签 | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 13 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_view
说明： 用户浏览商品记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | model_id | uuid |  |  |  |  |  | 被访问数据id | 
 | 3 | from_model | varchar |  |  |  |  |  | 被访问数据表 | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_wallet_apply
说明： 用户提现
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | get_type | varchar |  |  |  | √ |  | 收款类型 bank=银行卡 | 
 | 3 | bank_info | varchar |  |  |  | √ |  | 打款信息 | 
 | 4 | card_no | varchar |  |  |  |  |  | 银行卡 | 
 | 5 | realname | varchar |  |  |  |  |  | 真实姓名 | 
 | 6 | status_msg | varchar |  |  |  | √ |  | 提现信息 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | money | float8 |  |  |  | √ | 0 | 提现金额 | 
 | 11 | charge_money | float8 |  |  |  | √ | 0 | 手续费 | 
 | 12 | service_fee | float8 |  |  |  | √ | 0 | 手续费率 | 
 | 13 | status | int4 |  |  |  |  | 0 | 提现状态。0=申请中,1=已打款,-1=已拒绝 | 
 | 14 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 15 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： user_wallet_log
说明： 用户提现记录
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  | 用户id | 
 | 2 | type | varchar |  |  |  |  |  | 变动类型 | 
 | 3 | wallet_type | varchar |  |  |  |  |  | 日志类型。money=余额,score=积分 | 
 | 4 | item_id | uuid |  |  |  | √ |  | 项目id | 
 | 5 | ext_info | varchar |  |  |  | √ |  | 附加字段 | 
 | 6 | oper_type | varchar |  |  |  |  |  | 操作人类型。user,store,admin,system | 
 | 7 | oper_id | uuid |  |  |  | √ |  | 操作人 | 
 | 8 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 9 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 10 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 11 | wallet | float8 |  |  |  | √ | 0 | 变动金额 | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 13 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： vmc
说明： 自助售货机。无状态变化时 3-20分钟间隔上报，有状态变化时 立即上报。 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | vmc_no | varchar |  |  |  |  |  | 设备编号、不能为空 | 
 | 2 | client_desc | varchar |  |  |  | √ |  | 客户端版本描述 | 
 | 3 | client_version | varchar |  |  |  | √ |  | 客户端版本号 | 
 | 4 | cab_list | varchar |  |  |  | √ |  | 货柜状态。如果不支持则不上传该字段 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | update_version | varchar |  |  |  | √ |  | 升级版本号 | 
 | 8 | cover_image | varchar |  |  |  | √ |  | 屏幕显示的素材url地址 | 
 | 9 | image | varchar |  |  |  | √ |  |  | 
 | 10 | address | varchar |  |  |  | √ |  |  | 
 | 11 | temple_id | varchar |  |  |  | √ |  |  | 
 | 12 | name | varchar |  |  |  | √ |  |  | 
 | 13 | type | varchar |  |  |  | √ |  |  | 
 | 14 | capacity | varchar |  |  |  | √ |  |  | 
 | 15 | firmware | varchar |  |  |  | √ |  | 下载升级的固件url地址 | 
 | 16 | scene_str | varchar |  |  |  | √ |  |  | 
 | 17 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 18 | replenishment_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 客户端上次补货时间 | 
 | 19 | client_status | int4 |  |  |  |  | 0 | 整机状态。 (0-正常 1-禁用 2-异常 暂停服务) | 
 | 20 | coins_status | int4 |  |  |  | √ | 0 | 硬币器状态。 (0-正常 1-禁用 2-故障) | 
 | 21 | note_status | int4 |  |  |  | √ | 0 | 纸币器状态。 (0-正常 1-禁用 2-故障) | 
 | 22 | print_status | int4 |  |  |  | √ | 0 | 打印机状态。(0-正常 1-纸已用完、2-纸快用完、4-切纸出错、8-打印机头过热、16-打印机盖开启) | 
 | 23 | pos_status | int4 |  |  |  | √ | 0 | POS机状态。 0-正常、1-禁用、2-故障 | 
 | 24 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 25 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 26 | last_poll_time | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 最后心跳时间 | 

#### 表名： vue_editor_items_config
说明： vue编辑器控件配置
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | type | varchar |  |  |  | √ |  | 类型 | 
 | 2 | category | varchar |  |  |  | √ |  | 分类 | 
 | 3 | name | varchar |  |  |  |  |  | 组件名称 | 
 | 4 | value | varchar |  |  |  | √ |  | 组件配置json | 
 | 5 | page_id | uuid |  |  |  |  |  | 归属页面ID | 
 | 6 | schema | varchar |  |  |  | √ |  | schema | 
 | 7 | ui_schema | varchar |  |  |  | √ |  | uiSchema | 
 | 8 | form_data | varchar |  |  |  | √ |  | formData | 
 | 9 | error_schema | varchar |  |  |  | √ |  | errorSchema | 
 | 10 | form_footer | varchar |  |  |  | √ |  | formFooter | 
 | 11 | form_props | uuid |  |  |  | √ |  | formProps | 
 | 12 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 13 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 14 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 15 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 16 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： vue_editor_pages
说明： vue编辑器页面
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 页面名称 | 
 | 2 | type | varchar |  |  |  |  |  | 页面类型 | 
 | 3 | image | varchar |  |  |  | √ |  | 页面预览图 | 
 | 4 | memo | varchar |  |  |  | √ |  | 备注 | 
 | 5 | platform | varchar |  |  |  | √ |  | 适用平台 | 
 | 6 | page_title | varchar |  |  |  | √ |  | 页面标题 | 
 | 7 | page_path | varchar |  |  |  | √ |  | 页面路径 | 
 | 8 | user_id | uuid |  |  |  | √ |  | 用户id | 
 | 9 | tags | varchar |  |  |  | √ |  | 分类标签 | 
 | 10 | description | varchar |  |  |  | √ |  | 页面说明 | 
 | 11 | page_id | uuid |  |  |  |  |  | 页面id。使用nanoid | 
 | 12 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 13 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 14 | edit_status | int4 |  |  |  |  | 0 | 编辑状态 | 
 | 15 | status | int4 |  |  |  |  | 0 | 状态 | 
 | 16 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 17 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 18 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechat_cloud
说明： 微信云
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | appid | varchar |  |  |  |  |  | appid | 
 | 2 | env | varchar |  |  |  |  |  | 云环境id | 
 | 3 | codesecret | varchar |  |  |  | √ |  | 代码秘钥 | 
 | 4 | info_list | varchar |  |  |  | √ |  | 环境信息 | 
 | 5 | config | varchar |  |  |  | √ |  | 小程序配置json | 
 | 6 | functions | varchar |  |  |  | √ |  | 云函数列表 | 
 | 7 | collections | varchar |  |  |  | √ |  | 集合信息 | 
 | 8 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 9 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 10 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 11 | status | int4 |  |  |  |  | 0 | 状态。-1=HALTED,0=UNAVAILABLE,1=NORMAL | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 13 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechat_graphic
说明： 微信图片
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | title | varchar |  |  |  |  |  | 标题 | 
 | 2 | author | varchar |  |  |  |  |  | 作者 | 
 | 3 | cover | varchar |  |  |  |  |  | 封面 | 
 | 4 | content | varchar |  |  |  |  |  | 内容 | 
 | 5 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 6 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 7 | parent_id | uuid |  |  |  | √ |  |  | 
 | 8 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 9 | status | int4 |  |  |  |  | 0 |  | 
 | 10 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 11 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechat_material
说明： 微信素材
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 标签名称 | 
 | 2 | tag_id | varchar |  |  |  | √ |  | 微信 tag id | 
 | 3 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 4 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 5 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 6 | fans_amount | int4 |  |  |  | √ | 0 | 粉丝数量 | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechat_menus
说明： 微信公众号菜单
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 菜单名称 | 
 | 2 | type | varchar |  |  |  |  |  | 类型 | 
 | 3 | key | varchar |  |  |  |  |  | key | 
 | 4 | url | varchar |  |  |  |  |  | view 类型  url 链接 | 
 | 5 | appid | varchar |  |  |  |  |  | 小程序appid | 
 | 6 | pagepath | varchar |  |  |  |  |  | 小程序页面 | 
 | 7 | media_id | varchar |  |  |  |  |  | 调用新增永久素材接口返回的合法media_id | 
 | 8 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 9 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 10 | parent_id | uuid |  |  |  | √ |  |  | 
 | 11 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 13 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechat_miniapp_version
说明： 小程序版本
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | product_id | uuid |  |  |  | √ |  | 商品id。即小程序模板对应第三方appstore的商品id | 
 | 2 | template_id | varchar |  |  |  |  |  | 第三方平台代码库中的代码模版ID | 
 | 3 | ext_json | varchar |  |  |  | √ |  | 第三方模板自定义的配置 | 
 | 4 | user_version | varchar |  |  |  | √ |  | 代码版本号。开发者可自定义 | 
 | 5 | user_desc | varchar |  |  |  | √ |  | 代码描述。开发者可自定义 | 
 | 6 | category_list | varchar |  |  |  | √ |  | 可填选的类目列表 | 
 | 7 | page_list | varchar |  |  |  | √ |  | 页面配置列表 | 
 | 8 | item_list | varchar |  |  |  | √ |  | 提交审核项的一个列表（至少填写1项，至多填写5项） | 
 | 9 | audit_id | varchar |  |  |  | √ |  | 提交审核时获得的审核id | 
 | 10 | reason | varchar |  |  |  | √ |  | 审核不通过原因 | 
 | 11 | appid | varchar |  |  |  |  |  | appid | 
 | 12 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 13 | audit_status | int4 |  |  |  |  | 0 | 审核状态。-1=未提交审核,0=审核成功,1=审核失败,2=审核中 | 
 | 14 | succ_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 审核成功时间 | 
 | 15 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 16 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 17 | fail_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 审核失败时间 | 
 | 18 | status | int4 |  |  |  |  | 0 | 代码状态 -1=已下线,0=未上传,1=已上传,2=已发布 | 
 | 19 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 20 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechat_reply
说明： 微信公众号消息
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | keyword | varchar |  |  |  | √ |  | 关键字 | 
 | 2 | media_id | varchar |  |  |  | √ |  | 微信资源ID | 
 | 3 | media_url | varchar |  |  |  | √ |  | 本地资源 URL | 
 | 4 | image_url | varchar |  |  |  | √ |  | 本地图片 URL | 
 | 5 | title | varchar |  |  |  | √ |  | 标题 | 
 | 6 | content | varchar |  |  |  |  |  | 内容 | 
 | 7 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 8 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 9 | appid | varchar |  |  |  | √ |  |  | 
 | 10 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 11 | type | int4 |  |  |  |  | 0 | 类型。1文字 2图文 3图片 4音乐 5视频 6语音 7转客服 | 
 | 12 | rule_type | int4 |  |  |  |  | 0 | 类型。1 关键字 2 关注 3 默认 | 
 | 13 | status | int4 |  |  |  |  | 0 | 1 正常 2 禁用 | 
 | 14 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 15 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechat_tags
说明： 微信标签
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  |  |  | 标签名称 | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | tag_id | int4 |  |  |  |  | 0 | 微信 tag_Id | 
 | 6 | fans_amount | int4 |  |  |  |  | 0 | 粉丝数量 | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechat_user_has_tags
说明： 微信用户标签
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  |  |  |  | 
 | 2 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 3 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 4 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 5 | tag_id | int4 |  |  |  |  | 0 |  | 
 | 6 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 7 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechatopen
说明： 微信第三方平台信息。详情参考 https   open.weixin.qq.com 
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | appid | varchar |  |  |  |  |  | appid | 
 | 2 | appsecret | varchar |  |  |  |  |  | appsecret | 
 | 3 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 4 | encoding_aes_key | varchar |  |  |  |  |  | encodingAesKey | 
 | 5 | component_verify_ticket | varchar |  |  |  | √ |  | componentVerifyTicket | 
 | 6 | component_access_token | varchar |  |  |  | √ |  | componentAccessToken | 
 | 7 | pre_auth_code | varchar |  |  |  | √ |  | 预授权码 | 
 | 8 | token | varchar |  |  |  |  |  | token | 
 | 9 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 10 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 11 | token_overtime | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | token过期时间 | 
 | 12 | pre_code_overtime | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 预授权过期时间 | 
 | 13 | status | int4 |  |  |  |  | 0 | 状态 | 
 | 14 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 15 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechatopen_applet
说明： 微信第三方平台绑定的应用
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | name | varchar |  |  |  | √ |  | 应用名称 | 
 | 2 | typedata | varchar |  |  |  | √ |  | 应用类型 | 
 | 3 | token | varchar |  |  |  | √ |  | token | 
 | 4 | appid | varchar |  |  |  |  |  | appid | 
 | 5 | appsecret | varchar |  |  |  | √ |  | appsecret | 
 | 6 | aeskey | varchar |  |  |  | √ |  | EncodingAESKey | 
 | 7 | mchid | varchar |  |  |  | √ |  | 微信支付商户号 | 
 | 8 | mchkey | varchar |  |  |  | √ |  | 商户支付密钥 | 
 | 9 | mch_api_cert | varchar |  |  |  | √ |  | 商户API证书cert | 
 | 10 | mch_api_key | varchar |  |  |  | √ |  | 商户API证书key | 
 | 11 | notify_url | varchar |  |  |  | √ |  | 微信支付异步通知url | 
 | 12 | principal | varchar |  |  |  | √ |  | 主体名称 | 
 | 13 | original | varchar |  |  |  | √ |  | 原始ID | 
 | 14 | wechat | varchar |  |  |  | √ |  | 微信号 | 
 | 15 | headface_image | varchar |  |  |  | √ |  | 头像 | 
 | 16 | qrcode_image | varchar |  |  |  | √ |  | 二维码图片 | 
 | 17 | signature | varchar |  |  |  | √ |  | 账号介绍 | 
 | 18 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 19 | status | int4 |  |  |  |  | 0 | 状态 | 
 | 20 | weigh | int4 |  |  |  |  | 0 | 权重 | 
 | 21 | service_type_info | varchar |  |  |  | √ |  | 授权方公众号类型 | 
 | 22 | verify_type_info | varchar |  |  |  | √ |  | 授权方认证类型 | 
 | 23 | business_info | varchar |  |  |  | √ |  | 用以了解公众号功能的开通状况 | 
 | 24 | authorizer_access_token | varchar |  |  |  | √ |  | 第三方平台授权token | 
 | 25 | authorizer_refresh_token | varchar |  |  |  | √ |  | 授权刷新token | 
 | 26 | miniprograminfo | varchar |  |  |  | √ |  | 小程序信息 | 
 | 27 | ticket | varchar |  |  |  | √ |  | jsapi ticket | 
 | 28 | ticket_overtime | varchar |  |  |  | √ |  | jsapi ticket 过期时间 | 
 | 29 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 30 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 31 | func_info | varchar |  |  |  | √ |  |  | 
 | 32 | basic_config | varchar |  |  |  | √ |  |  | 
 | 33 | redirect_url | varchar |  |  |  | √ |  |  | 
 | 34 | access_token_overtime | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 授权token过期时间 | 
 | 35 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 36 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 37 | channels_info | int4 |  |  |  | √ | 0 |  | 
 | 38 | register_type | int4 |  |  |  | √ | 0 |  | 

#### 表名： wechatopen_miniapp_domains
说明： 小程序域名配置
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | appid | varchar |  |  |  |  |  | appid | 
 | 2 | requestdomain | varchar |  |  |  | √ |  | requestdomain | 
 | 3 | wsrequestdomain | varchar |  |  |  | √ |  | wsrequestdomain | 
 | 4 | uploaddomain | varchar |  |  |  | √ |  | uploaddomain | 
 | 5 | downloaddomain | varchar |  |  |  | √ |  | downloaddomain | 
 | 6 | udpdomain | varchar |  |  |  | √ |  | udpdomain | 
 | 7 | tcpdomain | varchar |  |  |  | √ |  | tcpdomain | 
 | 8 | effective_domain | varchar |  |  |  | √ |  | effectiveDomain | 
 | 9 | ext_domain | varchar |  |  |  | √ |  | extDomain | 
 | 10 | effective_webviewdomain | varchar |  |  |  | √ |  | effectiveWebviewdomain | 
 | 11 | ext_webviewdomain | varchar |  |  |  | √ |  | extWebviewdomain | 
 | 12 | file_name | varchar |  |  |  | √ |  | file_name | 
 | 13 | file_content | varchar |  |  |  | √ |  | file_content | 
 | 14 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 15 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 16 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 17 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 18 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechatopen_miniapp_users
说明： 小程序用户
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  | √ |  | 关联管理后台users表ID | 
 | 2 | ai_user_id | uuid |  |  |  | √ |  | AI子系统用户ID | 
 | 3 | appid | varchar |  |  |  |  |  | 关联applet表appid | 
 | 4 | openid | varchar |  |  |  |  |  | openid | 
 | 5 | unionid | varchar |  |  |  | √ |  | 微信第三方平台用户统一标识 | 
 | 6 | nickname | varchar |  |  |  | √ |  | 用户昵称 | 
 | 7 | phone_number | varchar |  |  |  | √ |  | 用户绑定的手机号（国外手机号会有区号） | 
 | 8 | pure_phone_number | varchar |  |  |  | √ |  | 没有区号的手机号 | 
 | 9 | country_code | varchar |  |  |  | √ |  | 区号 | 
 | 10 | password | varchar |  |  |  | √ |  | 登录密码 | 
 | 11 | city | varchar |  |  |  | √ |  | 城市 | 
 | 12 | province | varchar |  |  |  | √ |  | 省份 | 
 | 13 | country | varchar |  |  |  | √ |  | 国家 | 
 | 14 | avatar_url | varchar |  |  |  | √ |  | 头像 | 
 | 15 | language | varchar |  |  |  | √ |  | 语言 | 
 | 16 | remark | varchar |  |  |  | √ |  | 运营者对粉丝的备注 | 
 | 17 | tagid_list | varchar |  |  |  | √ |  | 用户被打上的标签ID列表 | 
 | 18 | subscribe_scene | varchar |  |  |  | √ |  | 用户使用的渠道来源 | 
 | 19 | qr_scene | varchar |  |  |  | √ |  | 二维码扫码场景（开发者自定义） | 
 | 20 | qr_scene_str | varchar |  |  |  | √ |  | 二维码扫码场景描述（开发者自定义） | 
 | 21 | privilege | varchar |  |  |  | √ |  | 用户特权信息。json数组 | 
 | 22 | loginip | varchar |  |  |  | √ |  | ip地址 | 
 | 23 | token | varchar |  |  |  | √ |  | token,自定义登录态请求api的标识，前端需缓存' | 
 | 24 | access_token | varchar |  |  |  | √ |  | access_token | 
 | 25 | session_key | varchar |  |  |  | √ |  | 会话密钥 | 
 | 26 | verification | varchar |  |  |  | √ |  | 验证 | 
 | 27 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 28 | gender | int4 |  |  |  | √ | 0 | 性别。1=男,2=女,0=未知 | 
 | 29 | ai_user_info | varchar |  |  |  | √ |  | AI子系统用户信息 | 
 | 30 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 31 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 32 | refresh_token | varchar |  |  |  | √ |  |  | 
 | 33 | subscribe | int4 |  |  |  |  | 0 | 是否使用该小程序标识。0=未关注，1=关注 | 
 | 34 | subscribe_time | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 关注时间 | 
 | 35 | access_token_overtime | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | access_token过期时间 | 
 | 36 | status | int4 |  |  |  |  | 0 | 状态 | 
 | 37 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 38 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechatopen_template
说明： 微信第三方平台小程序模板
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | draft_id | uuid |  |  |  |  |  | 草稿id | 
 | 2 | template_id | uuid |  |  |  |  |  | 模板id | 
 | 3 | user_version | varchar |  |  |  | √ |  | 版本号 | 
 | 4 | user_desc | varchar |  |  |  | √ |  | 版本描述开发者自定义字段 | 
 | 5 | source_miniprogram_appid | varchar |  |  |  | √ |  | 开发小程序的appid | 
 | 6 | source_miniprogram | varchar |  |  |  | √ |  | 开发小程序的名称 | 
 | 7 | category_list | varchar |  |  |  | √ |  | 标准模板的类目信息；如果是普通模板则值为空的数组' | 
 | 8 | reason | varchar |  |  |  | √ |  | 标准模板的审核驳回的原因，；普通模板不返回该值 | 
 | 9 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 10 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 11 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 12 | create_time | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 开发者上传草稿时间戳 | 
 | 13 | template_type | int4 |  |  |  |  | 0 | 0对应普通模板，1对应标准模板 | 
 | 14 | audit_scene | int4 |  |  |  |  | 0 | 标准模板的场景标签；普通模板不返回该值' | 
 | 15 | audit_status | int4 |  |  |  |  | 0 | 标准模板的审核状态；普通模板不返回该值' | 
 | 16 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 17 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechatopen_template_draft
说明： 微信第三方平台小程序草稿箱
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | draft_id | varchar |  |  |  |  |  | 草稿id | 
 | 2 | user_version | varchar |  |  |  | √ |  | 版本号 | 
 | 3 | user_desc | varchar |  |  |  | √ |  | 版本描述开发者自定义字段 | 
 | 4 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 5 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 6 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 7 | create_time | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 开发者上传草稿时间戳 | 
 | 8 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 9 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechatopen_users
说明： 公众号用户
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  | √ |  | 用户ID | 
 | 2 | ai_user_id | uuid |  |  |  | √ |  |  | 
 | 3 | appid | varchar |  |  |  |  |  | appid | 
 | 4 | openid | varchar |  |  |  |  |  | openid | 
 | 5 | unionid | varchar |  |  |  | √ |  | 用户统一标识 | 
 | 6 | nickname | varchar |  |  |  | √ |  | 用户昵称 | 
 | 7 | phone_number | varchar |  |  |  | √ |  | 手机号码 | 
 | 8 | pure_phone_number | varchar |  |  |  | √ |  |  | 
 | 9 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 10 | country_code | varchar |  |  |  | √ |  | 国家 | 
 | 11 | password | varchar |  |  |  | √ |  | 登录密码 | 
 | 12 | city | varchar |  |  |  | √ |  | 城市 | 
 | 13 | province | varchar |  |  |  | √ |  | 省份 | 
 | 14 | country | varchar |  |  |  | √ |  | 国家 | 
 | 15 | avatar_url | varchar |  |  |  | √ |  | 用户头像 | 
 | 16 | language | varchar |  |  |  | √ |  | 用户的语言 | 
 | 17 | remark | varchar |  |  |  | √ |  | 公众号运营者对粉丝的备注 | 
 | 18 | tagid_list | varchar |  |  |  | √ |  | 用户被打上的标签ID列表 | 
 | 19 | subscribe_scene | varchar |  |  |  | √ |  | 返回用户关注的渠道来源 | 
 | 20 | qr_scene | varchar |  |  |  | √ |  | 二维码扫码场景（开发者自定义） | 
 | 21 | qr_scene_str | varchar |  |  |  | √ |  | 二维码扫码场景描述（开发者自定义） | 
 | 22 | privilege | varchar |  |  |  | √ |  | 用户特权信息，json数组 | 
 | 23 | loginip | varchar |  |  |  | √ |  | IP地址 | 
 | 24 | token | varchar |  |  |  | √ |  | token | 
 | 25 | access_token | varchar |  |  |  | √ |  | access_token | 
 | 26 | session_key | varchar |  |  |  | √ |  |  | 
 | 27 | verification | varchar |  |  |  | √ |  | 验证 | 
 | 28 | ai_user_info | varchar |  |  |  | √ |  |  | 
 | 29 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 30 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 31 | refresh_token | varchar |  |  |  | √ |  |  | 
 | 32 | scope | varchar |  |  |  | √ |  |  | 
 | 33 | gender | int4 |  |  |  | √ | 0 | 性别。1=男性，2=女性 | 
 | 34 | subscribe | int4 |  |  |  | √ | 0 | 是否订阅该公众号标识。0=未关注，1=关注 | 
 | 35 | subscribe_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | 用户关注时间。为时间戳 | 
 | 36 | access_token_overtime | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | access_token_overtime | 
 | 37 | status | int4 |  |  |  |  | 0 | 状态 | 
 | 38 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 39 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wechatpay_transaction
说明： 微信支付流水
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | notify_id | varchar |  |  |  |  |  | 通知ID | 
 | 2 | transaction_id | varchar |  |  |  |  |  | 微信支付订单号 | 
 | 3 | mchid | varchar |  |  |  |  |  | 商户号 | 
 | 4 | appid | varchar |  |  |  |  |  | appid | 
 | 5 | out_trade_no | varchar |  |  |  |  |  | 商户支付订单号 | 
 | 6 | trade_state | varchar |  |  |  |  |  | 交易状态。SUCCESS=支付成功,REFUND=转入退款,NOTPAY=未支付,CLOSED=已关闭,REVOKED=已撤销（付款码支付）,USERPAYING=用户支付中（付款码支付）,PAYERROR=支付失败(其他原因，如银行返回失败)  | 
 | 7 | trade_state_desc | varchar |  |  |  |  |  | 交易状态描述 | 
 | 8 | bank_type | varchar |  |  |  |  |  | 付款银行 | 
 | 9 | trade_type | varchar |  |  |  |  |  | 交易类型。JSAPI=公众号支付,NATIVE=扫码支付,APP=APP支付,MICROPAY=付款码支付,MWEB=H5支付,FACEPAY=刷脸支付' | 
 | 10 | attach | varchar |  |  |  | √ |  | 附加数据 | 
 | 11 | payer | varchar |  |  |  |  |  | 支付者。json包含用户标识 openid | 
 | 12 | amount | varchar |  |  |  |  |  | 订单金额信息json | 
 | 13 | scene_info | varchar |  |  |  | √ |  | 支付场景信息描述json | 
 | 14 | promotion_detail | varchar |  |  |  | √ |  | 优惠功能 | 
 | 15 | is_subscribe | varchar |  |  |  | √ |  | 是否关注公众号 | 
 | 16 | resource_type | varchar |  |  |  | √ |  | 通知数据类型 | 
 | 17 | event_type | varchar |  |  |  | √ |  | 通知类型 | 
 | 18 | resource_algorithm | varchar |  |  |  | √ |  | 加密算法类型 | 
 | 19 | resource_ciphertext | varchar |  |  |  | √ |  | 数据密文 | 
 | 20 | resource_nonce | varchar |  |  |  | √ |  | 随机串 | 
 | 21 | resource_original_type | varchar |  |  |  | √ |  | 原始类型 | 
 | 22 | resource_associated_data | varchar |  |  |  | √ |  | 附加数据 | 
 | 23 | summary | varchar |  |  |  | √ |  | 回调摘要 | 
 | 24 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 25 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 26 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 27 | success_time | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 支付完成时间 | 
 | 28 | create_time | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 通知创建时间 | 
 | 29 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 30 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： wxa_updatable_message
说明： 微信消息通知
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | user_id | uuid |  |  |  | √ |  | 小程序用户表id | 
 | 2 | id | uuid |  | √ |  |  | gen_random_uuid |  | 
 | 3 | openid | varchar |  |  |  | √ |  | openid | 
 | 4 | unionid | varchar |  |  |  | √ |  | unionid | 
 | 5 | activity_id | varchar |  |  |  | √ |  | 动态消息的 ID | 
 | 6 | iv | varchar |  |  |  | √ |  | 加密算法的初始向量。详细见加密数据解密算法 | 
 | 7 | encrypted_data | varchar |  |  |  | √ |  | 经过加密的activity_id。解密后可得到原始的activity_id | 
 | 8 | share_ticket | varchar |  |  |  | √ |  | shareTicket | 
 | 9 | member_count | varchar |  |  |  | √ |  | 状态。 0 时有效，文字内容模板中 member_count 的值 | 
 | 10 | room_limit | varchar |  |  |  | √ |  | 状态。 0 时有效，文字内容模板中 room_limit 的值 | 
 | 11 | path | varchar |  |  |  | √ |  | 状态。 1 时有效，点击「进入」启动小程序时使用的路径 | 
 | 12 | version_type | varchar |  |  |  | √ |  | 状态。 1 时有效，点击「进入」启动小程序时使用的路径 | 
 | 13 | template_info | varchar |  |  |  | √ |  | 动态消息对应的模板信息 | 
 | 14 | to_openid | varchar |  |  |  | √ |  | 接收人openid | 
 | 15 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 16 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 
 | 17 | expiration_time | timestamptz |  |  |  | √ | CURRENT_TIMESTAMP | activity_id 的过期时间戳。默认24小时后过期。 | 
 | 18 | valid | int4 |  |  |  | √ | 0 | 验证是否通过 | 
 | 19 | target_state | int4 |  |  |  | √ | 0 | 动态消息修改后的状态。0=未开始，1=已开始 | 
 | 20 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 21 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： agent_skills
说明： Agent技能管理。用于管理Agent Skills运行时的技能包，支持从GitHub、Gitee、AtomGit等平台搜索和安装技能，支持AI大模型生成技能。
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | id | uuid |  | √ |  |  | gen_random_uuid | 技能唯一标识 | 
 | 2 | name | varchar |  |  |  |  |  | 技能名称（1-64字符） | 
 | 3 | description | varchar |  |  |  | √ |  | 技能描述（1-1024字符） | 
 | 4 | source | varchar |  |  |  | √ |  | 来源平台（github/gitee/atomgit/local） | 
 | 5 | source_url | varchar |  |  |  | √ |  | 源码仓库URL | 
 | 6 | source_type | varchar |  |  |  | √ |  | 源类型（repository/archive/local） | 
 | 7 | branch | varchar |  |  |  | √ |  | Git分支名称 | 
 | 8 | tag | varchar |  |  |  | √ |  | Git标签名称 | 
 | 9 | commit | varchar |  |  |  | √ |  | Git提交哈希 | 
 | 10 | version | varchar |  |  |  | √ |  | 技能版本号 | 
 | 11 | author | varchar |  |  |  | √ |  | 作者 | 
 | 12 | homepage | varchar |  |  |  | √ |  | 主页地址 | 
 | 13 | license | varchar |  |  |  | √ |  | 许可证 | 
 | 14 | keywords | varchar |  |  |  | √ |  | 关键词（逗号分隔） | 
 | 15 | tags | varchar |  |  |  | √ |  | 标签（JSON数组） | 
 | 16 | categories | varchar |  |  |  | √ |  | 分类（JSON数组） | 
 | 17 | install_path | varchar |  |  |  | √ |  | 安装路径 | 
 | 18 | compatibility | varchar |  |  |  | √ |  | 兼容性要求（最大500字符） | 
 | 19 | allowed_tools | varchar |  |  |  | √ |  | 预批准工具列表（JSON数组） | 
 | 20 | dependencies | varchar |  |  |  | √ |  | 依赖列表（JSON数组） | 
 | 21 | permissions | varchar |  |  |  | √ |  | 权限要求（JSON数组） | 
 | 22 | parameters | varchar |  |  |  | √ |  | 参数定义（JSON数组） | 
 | 23 | instructions | varchar |  |  |  | √ |  | 技能指令和指南（Markdown） | 
 | 24 | scripts_dir_exists | int4 |  |  |  |  | 0 | scripts目录是否存在。0=否，1=是 | 
 | 25 | references_dir_exists | int4 |  |  |  |  | 0 | references目录是否存在。0=否，1=是 | 
 | 26 | assets_dir_exists | int4 |  |  |  |  | 0 | assets目录是否存在。0=否，1=是 | 
 | 27 | status | int4 |  |  |  |  | 0 | 安装状态。0=未安装，1=已安装，2=安装失败，3=已卸载 | 
 | 28 | runtime_status | varchar |  |  |  | √ |  | 运行状态（idle/running/error/disabled） | 
 | 29 | validation_status | varchar |  |  |  | √ |  | 验证状态（valid/invalid/pending） | 
 | 30 | validation_errors | varchar |  |  |  | √ |  | 验证错误信息（JSON） | 
 | 31 | last_validated_at | timestamptz |  |  |  | √ |  | 最后验证时间 | 
 | 32 | config | varchar |  |  |  | √ |  | 运行时配置（JSON格式） | 
 | 33 | env_vars | varchar |  |  |  | √ |  | 环境变量配置（JSON格式） | 
 | 34 | timeout | int4 |  |  |  |  | 30000 | 执行超时时间（毫秒） | 
 | 35 | retry_count | int4 |  |  |  |  | 0 | 重试次数 | 
 | 36 | run_count | int4 |  |  |  |  | 0 | 总运行次数 | 
 | 37 | success_count | int4 |  |  |  |  | 0 | 成功运行次数 | 
 | 38 | error_count | int4 |  |  |  |  | 0 | 错误运行次数 | 
 | 39 | last_run_at | timestamptz |  |  |  | √ |  | 最后运行时间 | 
 | 40 | last_error | varchar |  |  |  | √ |  | 最后错误信息 | 
 | 41 | avg_execution_time | int4 |  |  |  |  | 0 | 平均执行时间（毫秒） | 
 | 42 | generation_prompt | varchar |  |  |  | √ |  | AI生成提示词 | 
 | 43 | generation_model | varchar |  |  |  | √ |  | 生成使用的模型（如gpt-4, claude-3） | 
 | 44 | generation_status | varchar |  |  |  | √ |  | 生成状态（pending/generating/completed/failed） | 
 | 45 | parent_skill_id | uuid |  |  |  | √ |  | 父技能ID（用于技能迭代生成） | 
 | 46 | extra_metadata | varchar |  |  |  | √ |  | 扩展元数据（JSON格式） | 
 | 47 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 48 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 49 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 50 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 

#### 表名： agent_skill_executions
说明： Agent技能执行历史。记录技能的每次执行情况，包括参数、结果、执行时间等。
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | id | uuid |  | √ |  |  | gen_random_uuid | 执行记录唯一标识 | 
 | 2 | skill_id | uuid |  |  |  | √ |  | 关联的技能ID | 
 | 3 | tool_name | varchar |  |  |  | √ |  | 执行的工具名称 | 
 | 4 | parameters | varchar |  |  |  | √ |  | 执行参数（JSON格式） | 
 | 5 | result | varchar |  |  |  | √ |  | 执行结果 | 
 | 6 | success | int4 |  |  |  |  | 0 | 是否成功。0=失败，1=成功 | 
 | 7 | error_message | varchar |  |  |  | √ |  | 错误信息 | 
 | 8 | execution_time | int4 |  |  |  |  | 0 | 执行时间（毫秒） | 
 | 9 | started_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 开始时间 | 
 | 10 | finished_at | timestamptz |  |  |  | √ |  | 结束时间 | 
 | 11 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 

#### 表名： agent_skill_configs
说明： Agent技能配置。存储技能的运行时配置项，支持动态配置管理。
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | id | uuid |  | √ |  |  | gen_random_uuid | 配置项唯一标识 | 
 | 2 | skill_id | uuid |  |  |  | √ |  | 关联的技能ID | 
 | 3 | config_key | varchar |  |  |  | √ |  | 配置键名 | 
 | 4 | config_value | varchar |  |  |  | √ |  | 配置值 | 
 | 5 | description | varchar |  |  |  | √ |  | 配置说明 | 
 | 6 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 7 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 8 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： agent_runtime_status
说明： Agent运行时状态。监控Agent Skills运行时的运行状态、版本、端口等信息。
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | id | uuid |  | √ |  |  | gen_random_uuid | 状态记录唯一标识 | 
 | 2 | runtime_version | varchar |  |  |  | √ |  | 运行时版本号 | 
 | 3 | status | varchar |  |  |  | √ |  | 运行状态（running/stopped/error） | 
 | 4 | port | int4 |  |  |  |  | 8080 | 监听端口 | 
 | 5 | host | varchar |  |  |  | √ |  | 主机地址 | 
 | 6 | pid | int4 |  |  |  | √ |  | 进程ID | 
 | 7 | started_at | timestamptz |  |  |  | √ |  | 启动时间 | 
 | 8 | stopped_at | timestamptz |  |  |  | √ |  | 停止时间 | 
 | 9 | last_check_at | timestamptz |  |  |  | √ |  | 最后检查时间 | 
 | 10 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 11 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 12 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 

#### 表名： chat_conversations
说明： 聊天会话表。存储智能体聊天会话的基本信息，包括模型配置、系统提示、状态等。
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | id | uuid |  | √ |  |  | gen_random_uuid | 会话唯一标识 | 
 | 2 | title | varchar |  |  |  | √ |  | 会话标题 | 
 | 3 | model_provider | varchar |  |  |  | √ |  | 模型提供商 | 
 | 4 | model_name | varchar |  |  |  | √ |  | 模型名称 | 
 | 5 | system_prompt | text |  |  |  | √ |  | 系统提示 | 
 | 6 | temperature | float8 |  |  |  |  | 0.7 | 温度参数 | 
 | 7 | max_tokens | int4 |  |  |  |  | 4096 | 最大令牌数 | 
 | 8 | status | int4 |  |  |  |  | 1 | 会话状态 | 
 | 9 | skill_ids | varchar |  |  |  | √ |  | 技能ID列表 | 
 | 10 | metadata | varchar |  |  |  | √ |  | 元数据 | 
 | 11 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 12 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
 | 13 | updated_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 更新时间 | 
 | 14 | deleted_at | timestamptz |  |  |  | √ |  | 删除时间 | 

#### 表名： chat_messages
说明： 聊天消息表。存储聊天会话中的具体消息，包括角色、内容、令牌使用情况、技能执行信息等。
 | 序号 | 列名 | 数据类型 | 长度 | 主键 | 自增 | 允许空 | 默认值 | 列说明 | 
 | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | 
 | 1 | id | uuid |  | √ |  |  | gen_random_uuid | 消息唯一标识 | 
 | 2 | conversation_id | uuid |  |  |  |  |  | 关联的会话ID | 
 | 3 | role | varchar |  |  |  |  |  | 消息角色 | 
 | 4 | content | text |  |  |  |  |  | 消息内容 | 
 | 5 | tokens_used | int4 |  |  |  |  | 0 | 使用的令牌数 | 
 | 6 | skill_executed | uuid |  |  |  | √ |  | 执行的技能ID | 
 | 7 | skill_result | text |  |  |  | √ |  | 技能执行结果 | 
 | 8 | metadata | varchar |  |  |  | √ |  | 元数据 | 
 | 9 | creator | uuid |  |  |  | √ |  | 创建人 | 
 | 10 | created_at | timestamptz |  |  |  |  | CURRENT_TIMESTAMP | 创建时间 | 
