
# 异常情况说明

## 日志配置文件默认加载问题

如果三方调用配置的日志文件为空或者路径配置错误，则按以下配置默认加载

```
{
	"appenders": [{
		"enabled": "false",
		"name": "console",
		"type": "console",
		"pattern": "[%D %T %m] [%L] [%l] (%S) %M"
	}, {
		"enabled": "true",
		"name": "file",
		"type": "file",
		"pattern": "[%D %T %m] [%L] [%l] (%S) %M",
		"properties": [{
			"name": "filename",
			"value": "root.log"
		}, {
			"name": "rotate",
			"value": "true"
		}, {
			"name": "maxsize",
			"value": "20M"
		}, {
			"name": "daily",
			"value": "false"
		}]
	}],
	"loggers": [{
		"name": "Demo",
		"level": "info",
		"appender-refs": [{
			"ref": "console"
		}, {
			"ref": "file"
		}]
	}],
	"root": {
		"level": "info",
		"appender-refs": [{
			"ref": "console"
		}, {
			"ref": "file"
		}]
	}
}
```
如果需要改变单个日志文件的默认大小，请修改logger_manager.cj中如下代码片段，再重新编译测试
```
"name": "maxsize",
"value": "20M"
```

## 日志配置文件file appender中相关property缺失或者不配置内容

- filename 不配置或者值为空，则设置默认值为root.log
- maxsize  不配置或者值为空，则设置默认值为20M
- rotate   不配置或者值为空，则设置默认值false
- daily    不配置或者值为空，则设置默认值false
- pattern  不配置或者值为空，则设置默认值为[%T %D %m] [%L][%l] (%S) %M

## 拆分日志文件可能打印的异常

#### 移动文件到其他路径下(File.move(sourcePath,destinationPath,bool))异常

- The destination path is empty 目的路径为空
- The destination path cannot contain null character 目的路径包含空字符
- Move '${sourcePath}' to '${destinationPath}' FAILED: Source path not exists 源路径不存在
- Move '${sourcePath}' to '${destinationPath}' FAILED: Destination path exists 目的路径已经存在
- Delete the destination file FAILED before moving the source file 移动源文件之前删除目的文件失败
- Move '${sourcePath}' to '${destinationPath}' FAILED: '${getCurrentErrnoMsg()}' 其他错误

#### 打开新文件(File(path, openOption))异常

- The file path cannot be empty 文件路径不能为空
- The file path cannot contain null character 文件路径不能包含空字符
- 其他错误（打开文件失败，当选项（openOption）为open时文件不存在）

## 日志文件写入可能打印的异常

- The file not opened,can not be written 文件没打开，不能写入
- The file does not have the write permission 文件没有写入权限
- The file write error 其他错误，文件写入错误

## 解析日志文件可能打印的异常

- xml file is empty! xml文件为空
- parse xml occur exception '${e.message}!' 解析xml文件发生异常：xxx
- get xml element occur exception '${e.message}'! 获取xml文件元素发生异常：xxx
- xml children element is empty! xml文件没有子元素
- can not find any element in xml file! xml文件中没有任何元素
- can not find any appender! xml文件配置无效(以appender配置判断)
- can not find any appender in xml file! 在xml文件中未发现任何appender配置
- can not find any logger in xml file! 在xml文件中未发现任何logger配置（不影响程序继续执行）
- root configuration has mistakes! root配置错误


