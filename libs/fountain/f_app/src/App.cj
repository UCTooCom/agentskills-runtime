/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_app

import f_version.*
import std.ast.*
import std.convert.*
import std.env.{getWorkingDirectory, getCommand, atExit, getStdOut}
import std.fs.*
import std.io.{StringReader, ByteBuffer, InputStream}
import std.process.*
import std.reflect.*
import std.regex.Regex
import std.time.MonoTime
import f_base.*
import f_log.impl.*

/**
 * App不会发生传参赋值，用命令行参数实例化后只调用boot函数。所以用struct比较合适，不会占用堆空间。
 */
public struct App {
    private static let log = LoggerFactory.getLogger<App>()
    private static const APP_STATIC_RESOURCE_SUFFIX = '_stAtIc__'
    private static let stdOut = getStdOut()

    public App(private let args: Array<String>,
               private let appHomeIsWorkingPath!: Bool = true,
               private let dynamic!: Bool = true,
               private let name!: String = '') {}
    private func convertArgs(first: String){
        match (this.args[0]) {
            case x where x == first => Array<String>(args.size - 1) {
                i => if (i == 0) {
                    x.replace('re', '')
                } else {
                    args[i + 1]
                }
            }
            case _ => args
        }
    }

    private func run(): Int64 {
        run(args)
    }
    private func confirmPath(args: Array<String>): (Int64, Path){
        var idx = 1
        var path = if (appHomeIsWorkingPath || args[0] == 'count' || idx >= args.size) {
            getWorkingDirectory()
        } else if (idx >= 1) {
            Path(args[1])
        } else if (idx >= 2) {
            Path(args[2])
        } else {
            let p = canonicalize(Path(getCommand()))
            if (p.parent.fileName == 'bin') {
                p.parent.parent
            } else {
                p.parent
            }
        }
        path = canonicalize(path)
        if(!exists(path)){
            Directory.create(path)
        }
        (idx, path)
    }
    private func confirmTargetPath(args: Array<String>){
        let path = if(args.size > 1){
            Path(args[1])
        }else{
            getWorkingDirectory()
        }
        if(!exists(path)){
            Directory.create(path)
        }
        canonicalize(path)
    }
    private func run(args: Array<String>): Int64{
        let path = confirmTargetPath(args)
        let (ext, libPathName, delim) = match (OS.current) {
            case Windows => (".dll", 'Path', ';')
            case macOS => (".dylib", 'DYLD_FALLBACK_LIBRARY_PATH', ':')
            case _ => (".so", 'LD_LIBRARY_PATH', ':')
        }
        func extractPattern() {
            var idx = 0
            for (i in 1..args.size where !args[i].startsWith("--dylibPattern=")) {
                idx = i
                break
            }
            idx++
            if (idx > 0) {
                let p = args[idx]['--dylibPattern='.size..]
                if ((p.startsWith("'") && p.endsWith("'")) || (p.startsWith('"') && p.endsWith('"'))) {
                    return p[1..p.size - 1]
                }
                p
            } else {
                ''
            }
        }
        func load(path: Path, pattern: Regex): Unit {
            Directory.walk(path) {
                fi =>
                log.debug{'scanning: ${fi.path}'}
                if (fi.isDirectory()) {
                    load(fi.path, pattern)
                } else if (fi.path.fileName.endsWith(ext) && pattern.matches(fi.path.fileNameWithoutExtension)) {
                    log.debug{"loading: ${fi.path}"}
                    PackageInfo.load(fi.path.toString().replace(ext, ''))
                }
                true
            }
        }
        if(dynamic){
            load(path, Regex('^lib.*(${extractPattern()}|.+${APP_STATIC_RESOURCE_SUFFIX}).*$'))
        }

        let beanFactoryType = try{
            ClassTypeInfo.get('f_bean.BeanFactory')
        }catch(_){
            None<ClassTypeInfo>
        }
        if(let Some(t) <- beanFactoryType){
            let instance = t.getStaticVariable('instance').getValue()
            let afterFn = t.getInstanceFunction('afterRegistered', [])
            afterFn.apply(instance, [])
        }
        let ticktockType = try{
            ClassTypeInfo.get('f_ticktock.Ticktock')
        }catch(_){
            None<ClassTypeInfo>
        }
        if(let Some(t) <- ticktockType){
            let getFn = t.getStaticFunction('loadTasks', [])
            getFn.apply(t, [])
        }
        let ormType = try{
            ClassTypeInfo.get('f_orm.ORM')
        }catch(_){
            None<ClassTypeInfo>
        }
        if(let Some(t) <- ormType){
            let initFn = t.getStaticFunction('initialize', [])
            initFn.apply(t, [])
        }
        let mvcTypeInfo = try{
            ClassTypeInfo.get('f_mvc.MVCStarter')
        }catch(_){
            None<ClassTypeInfo>
        }
        var startFn = None<StaticFunctionInfo>
        if(let Some(t) <- mvcTypeInfo){
            let initFn = t.getStaticFunction('initialize', [])
            initFn.apply(t, [])
            startFn = t.getStaticFunction('start', [])
        }
        //orm 会在初始化第一个DAO时初始化orm包，此时会从配置获得数据库连接配置从而完成orm初始化
        //执行load函数时一定会加载初始化orm的动态链接库从而完成初始化
        //其它模块是工具API没有专门的初始化API
        let app = this.app(path)
        let appver = if(AppVersion.version.isEmpty()){
            ''
        }else{
            '(${AppVersion.version})'
        }
        stdOut.writeln(
            AppVersion.banner + OS.current.nextLine + 
            '${app}${appver} started by ${versionStr} in ${MonoTime.now() - AppStarts}')
        if(let Some(t) <- mvcTypeInfo){
            startFn?.apply(t, [])
        }
        0
    }
    private let versionStr = FountainVersion
    private func version(){
        if (this.args.size == 1) {
            stdOut.writeln(versionStr)
        } else {
            stdOut.writeln('project is going to be committed, after editing version. Please confirm git has been installed and can be operated without password.')
            let v = args[1]
            if (v.isEmpty()) {
                stdOut.writeln('current version is ${versionStr}. To execute fboot version x.y.z, if you want to edit version.')
            } else if (Regex(#'^\d+\.\d+.\d+$'#).matches(v)) {
                var code = execute('git', ['pull'])
                if (code != 0) {
                    return code
                }
                let tomlPath = getWorkingDirectory().join('cjpm.toml')
                let reader = StringReader(ByteBuffer(File.readFrom(tomlPath)))
                let toml = StringGenerator()
                let versionRegex = Regex(#'^\s*version\s*=\s*"(\d+\.)+\d+"$'#)
                let cjcVersionRegex = Regex(#'^\s*cjc-version\s*=\s*"(\d+\.)+\d+"$'#)
                for (line in reader.lines()) {
                    func genLine(){
                        if (versionRegex.matches(line)) {
                            return '  version = "${v}"'
                        }else if (cjcVersionRegex.matches(line)) {
                            try{
                                if(let (code, stdout, _) <- executeWithOutput('cjc', ['-v']) && code == 0){
                                    let cjcv = String.fromUtf8(stdout).split('\n')[0].replace('Cangjie Compiler: ', '').replace(' (cjnative)', '').replace('\r', '').trimAscii()
                                    return '  cjc-version = "${cjcv}"'
                                }
                            }catch(e: Exception){
                                log.warn('error occurred on cjc -v', e)
                            }
                        }
                        line
                    }
                    toml.appendUnixNewLine(genLine())
                }
                File.writeTo(tomlPath, toml.unsafeBytes())
                replaceVersion(v)
                code = execute('git', ['add', '.'])
                if(code != 0){
                    return code
                }
                var msg = ''
                code = execute('git', ['commit', '-m', if (args.size > 2 && args[2] != 'tag') {
                    msg = '${args[2]}, version: ${v}'
                    msg
                } else {
                    msg = 'version: ${v}'
                    'Some codes were changed, ${msg}'
                }])
                if (code != 0) {
                    return code
                }

                let tagmsg = if(args.size > 3 && args[3] == 'tag'){
                    args[3 .. ]
                } else if (args.size > 2 && args[2] == 'tag') {
                    args[2 ..]
                } else {
                    Array<String>()
                }
                if (tagmsg.size > 0) {
                    msg += if (tagmsg.size > 1) {
                        '\n${args[1]}'
                    } else {
                        ''
                    }
                    code = if (msg.isEmpty()) {
                        execute('git', ['tag', 'release-${v}'])
                    } else{
                        execute('git', ['tag', '-a', 'release-${v}', '-m', msg])
                    }
                    if (code != 0) {
                        if (msg.isEmpty()) {
                            stdOut.writeln('git tag release-${v} FAILED, git push is to be executed.')
                        } else {
                            stdOut.writeln('git tag -a release-${v} -m ${msg} FAILED, git push is to be executed.')
                        }
                        return code
                    }
                }
                code = execute('git', ['push'])
                if (code != 0) {
                    stdOut.writeln('git push FAILED')
                    return code
                }
                execute('git', ['push', 'origin', 'release-${v}'])
            } else {
                stdOut.writeln('Format of version must be x.y.z, but ${v} was specified.')
            }
        }
        0
    }
    private func app(path: Path): String {
        if (name.size > 0) {
            name
        } else if (path.toString().endsWith('/target/release')) {
            path.parent.parent.fileName
        } else if (path.toString().endsWith('/release')) {
            path.parent.fileName
        } else {
            path.fileName
        }
    }
    private func pid() {
        Int64.parse(args[1])
    }
    private func shutdown(): Int64 {
        //每个模块都注册了atExit，所以发送退出命令的时候都会执行atExit
        let pid = this.pid()
        shutdown(pid)
    }
    private func shutdown(pid: Int64): Int64 {
        shutdown(pid, findProcess(pid))
    }
    private func shutdown(pid: Int64, process: Process): Int64 {
        process.terminate()
        while (true) {
            try {
                findProcess(pid)
            } catch (_: ProcessException) {
                break
            }
        }
        0
    }
    private func restart(){
        shutdown()
        run()
    }
    private func directories(path: Path){
        if(path == getWorkingDirectory()){
            let p = Path('${path}/${path.fileName}')
            if(!exists(p)){
                Directory.create(p, recursive: true)
            }
            (path, p)
        }else{
            (getWorkingDirectory(), path)
        }
    }
    private func entireFileText(path: Path){
        String.fromUtf8(File.readFrom(path))
    }
    private func appendToml(dir: Path): Unit {
        let tomlPath = dir.join('cjpm.toml')
        var content = entireFileText(tomlPath).replace('[workspace]', '''
[workspace]
  version = "1.0.0"'''
)
.replace('compile-option = ""', 'compile-option = "-O2 --dy-std -Woff all"')
.replace('override-compile-option = ""', 'override-compile-option = "-O2 --dy-std -Woff all"')
.replace('[dependencies]', '''
[dependencies]
  fountain = {git = "https://gitcode.com/Cangjie-SIG/fountain.git", branch = "lts/1.0.0"}'''
)
        content = '''
${content}

[profile.build]
  incremental = true

[target]
[target.x86_64-unknown-linux-gnu]
  compile-option = "-O2 --lto=full --dy-std -Woff all -ldl"
  override-compile-option = "-O2 --lto=full --dy-std -Woff all -ldl"
[target.x86_64-unknown-linux-gnu.bin-dependencies]
  path-option = ["\${CANGJIE_STDX_DYNAMIC_PATH}", "\${CANGJIE_FOUNTAIN_LIBS}"]
[target.aarch64-unknown-linux-gnu]
  compile-option = "-O2 --lto=full --dy-std -Woff all -ldl"
  override-compile-option = "-O2 --lto=full --dy-std -Woff all -ldl"
[target.aarch64-unknown-linux-gnu.bin-dependencies]
  path-option = ["\${CANGJIE_STDX_DYNAMIC_PATH}", "\${CANGJIE_FOUNTAIN_LIBS}"]
[target.x86_64-w64-mingw32]
  compile-option = "-O2 --dy-std -Woff all -lcrypt32"
  override-compile-option = "-O2 --dy-std -Woff all -lcrypt32"
[target.x86_64-w64-mingw32.bin-dependencies]
  path-option = ["\${CANGJIE_STDX_DYNAMIC_PATH}", "\${CANGJIE_FOUNTAIN_LIBS}"]
[target.x86_64-apple-darwin]
  compile-option = "-O2 --dy-std -Woff all"
  override-compile-option = "-O2 --dy-std -Woff all"
[target.x86_64-apple-darwin.bin-dependencies]
  path-option = ["\${CANGJIE_STDX_DYNAMIC_PATH}", "\${CANGJIE_FOUNTAIN_LIBS}"]
[target.aarch64-apple-darwin]
  compile-option = "-O2 --dy-std -Woff all"
  override-compile-option = "-O2 --dy-std -Woff all"
[target.aarch64-apple-darwin.bin-dependencies]
  path-option = ["\${CANGJIE_STDX_DYNAMIC_PATH}", "\${CANGJIE_FOUNTAIN_LIBS}"]
[target.aarch64-linux-ohos]
  compile-option = "-O2 --dy-std -ldl"
  override-compile-option = "-O2 --dy-std -ldl"
[target.aarch64-linux-ohos.bin-dependencies]
  path-option = ["\${CANGJIE_STDX_DYNAMIC_PATH}, "\${CANGJIE_FOUNTAIN_LIBS}""]
[target.x86_64-linux-ohos]
  compile-option = "-O2 --dy-std -ldl"
  override-compile-option = "-O2 --dy-std -ldl"
[target.x86_64-linux-ohos.bin-dependencies]
  path-option = ["\${CANGJIE_STDX_DYNAMIC_PATH}, "\${CANGJIE_FOUNTAIN_LIBS}""]
'''
        File.writeTo(tomlPath, content.unsafeBytes())
        // var path = dir.join('run')
        // Directory.create(path, recursive: true)
        // File.writeTo(path.join('cjpm.toml'), content.unsafeBytes())
        // path = dir.join('test')
        // Directory.create(path, recursive: true)
        // File.writeTo(path.join('cjpm.toml'), content.replace('-O2', '-O0 -g').replace('--lto=full', '').unsafeBytes())
    }
    private func doInit(arg: String): (Int64, Path) {
        let workingDir = if(1 < this.args.size){
            let sub = this.args[1]
            let dir = if(sub.startsWith('/')){
                Path(sub)
            } else {
                getWorkingDirectory().join(this.args[1])
            }
            if(!exists(dir)){
                Directory.create(dir, recursive: true)
            }
            dir
        }else{
            getWorkingDirectory()
        }
        let code = execute('cjpm', ['init', arg], workingDirectory: workingDir)
        (code, workingDir)
    }
    private func initWorkspace(): Int64 {
        let (code, dir) = doInit('--workspace')
        if(code != 0){
            return code
        }
        appendToml(dir)
        code
    }
    private func initModule(): Int64 {
        let (code, dir) = doInit('--type=dynamic')
        if(code != 0){
            return code
        }
        if(dir == getWorkingDirectory() || dir.parent == getWorkingDirectory()){
            addModule(dir.parent, dir.fileName)
        }
        try (file = File.create(dir.join('src/${dir.fileName}.cj'))) {
            file.write('package ${dir.fileName}\n\n'.unsafeBytes())
        }
        code
    }
    private func cleanUpdate(): Int64 {
        let path = confirmTargetPath(args)
        let (workingDir, targetDir) = directories(path)
        stdOut.writeln('fboot cleanUpdate ${workingDir} --target-dir=${targetDir}')
        let code = execute('cjpm', ['clean', '--target-dir=${targetDir}'], workingDirectory: workingDir)
        if(code != 0){
            return code
        }
        removeIfExists('${workingDir}/cjpm.lock')
        execute('cjpm', ['update'], workingDirectory: workingDir)
    }
    private func extract(dir: Path){
        var version = ''
        var name = ''
        try(file = File(dir.join('cjpm.toml'), Read)){
            let reader = StringReader(file)
            for (line in reader.lines()) {
                let l = line.trimAscii()
                if (l.startsWith('version') && let Some(idx) <- l.indexOf('"')) {
                    version = l[idx + 1 .. l.size - 1]
                } else if (l.startsWith('name') && let Some(idx) <- l.indexOf('"')) {
                    name = l[idx + 1 .. l.size - 1]
                }
                if (!(version.isEmpty() || name.isEmpty())) {
                    break
                }
            }
        }
        (version, if (name.isEmpty()) {
            dir.fileName
        } else {
            name
        })
    }
    private func banner(): String {
        let path = getWorkingDirectory().join('banner.txt')
        if(exists(path) && let banner <- entireFileText(path) && !banner.trimAscii().isEmpty()) {
            return banner
        }
#'
  _____                    __         .__
_/ ____\____  __ __  _____/  |______  |__| ____
\   __\/  _ \|  |  \/    \   __\__  \ |  |/    \
 |  | (  <_> )  |  /   |  \  |  / __ \|  |   |  \
 |__|  \____/|____/|___|  /__| (____  /__|___|  /
                        \/          \/        \/'#.removePrefix('\n')
    }
    private func replaceVersion(version: String) {
        let workingDir = getWorkingDirectory()
        stdOut.writeln('fboot replace version ${workingDir} ${version}')
        let fountainPath =
        match(workingDir.fileName) {
            case 'fountain' =>
            workingDir
            case 'fboot' =>
            workingDir.parent
            case _ =>
            stdOut.writeln('working directory ${workingDir} is not path of project fountain')
            return
        }
        if(!version.isEmpty()) {
            let appPath = fountainPath.join('f_version/src/FountainVersion.cj')
            var code = entireFileText(appPath)
            code = Regex(#'fountain\((\d+\.)+\d+\)'#).replaceAll(code, 'fountain(${version})')
            code = Regex(#'release-(\d+\.)+\d+'#).replaceAll(code, 'release-${version}')
            File.writeTo(appPath, code.unsafeBytes())
        }
    }
    private func appVersionModuleName(name: String): String {
        '${name}${APP_STATIC_RESOURCE_SUFFIX}'
    }
    private func genCode(name: String, version: String) {
'''
package ${appVersionModuleName(name)}
import fountain.version.AppVersion
private let _ = AppVersion.set(#'${banner()}'#, '${name}', '${version}')
'''
    }
    private func addModule(dir: Path, module: String): (String, String, Path) {
        let tomlPath = dir.join('cjpm.toml')
        let moduleMember = ', "./${module}"]'
        let toml = entireFileText(tomlPath)
        if(!toml.contains(moduleMember) && let Some(membersIdx) <- toml.indexOf('members') && let Some(idx) <- toml.indexOf(']', membersIdx)) {
            let members = toml[membersIdx ..= idx]
            let newMembers = members.replaceLast(']', moduleMember).replace('[, ', '[')
            let newtoml = toml.replaceFirst(members, newMembers)
            File.writeTo(tomlPath, newtoml.unsafeBytes())
        }
        (toml, moduleMember, tomlPath)
    }
    private func doBuild(path: Path, args: Array<String>): Int64 {
        stdOut.writeln('fboot build is used to compile the project which depends fountain.')
        let (workingDir, targetDir) = directories(path)
        stdOut.writeln('fboot build ${workingDir} --target-dir=${targetDir}')
        var (version, name) = extract(workingDir)
        let n = name.replace('.', '_').replace('-', '_')
        let versionModuleName = appVersionModuleName(n)
        let versionModuleDir = workingDir.join(versionModuleName)
        let (toml, versionModuleMember, tomlPath) = addModule(workingDir, versionModuleName)
        atExit{
            if (toml.size > 0) {
                File.writeTo(tomlPath, toml.replace(versionModuleMember, ']').unsafeBytes())
            }
            removeIfExists(versionModuleDir, recursive: true)
        }
        removeIfExists(versionModuleDir, recursive: true)
        Directory.create(versionModuleDir, recursive: true)
        var execode = execute('cjpm', ['init', '--type=dynamic'], workingDirectory: versionModuleDir)
        if (execode != 0) {
            return execode
        }
        let appVersionPath = versionModuleDir.join('src/${n}_AppVersion.cj')
        File.writeTo(appVersionPath, genCode(n, version).unsafeBytes())
        let argArray = Array<String>(2 + args.size){i => 
            match(i){
                case 0 => 'build'
                case 1 => '--target-dir=${targetDir}'
                case _ => args[i - 2]
            }
        }
        stdOut.writeln('BUILD ARGS: ${argArray}')
        execute('cjpm', argArray, workingDirectory: workingDir)
    }
    private func copyToml(source: String, path: Path){
        copy(path.join('${source}/cjpm.toml'), to: path.join('cjpm.toml'), overwrite: true)
    }
    private func confirmBuildArgs(){
        let (path, args) = if(this.args.size > 1 && !this.args[1].startsWith('-')){
            (Path(this.args[1]), this.args[2 ..])
        }else{
            (getWorkingDirectory(), this.args[1 ..])
        }
        if(!exists(path)){
            Directory.create(path)
        }
        (canonicalize(path), args)
    }
    private func build(){
        let (path, args) = confirmBuildArgs()
        doBuild(path, args)
    }
    private func test(): Int64 {
        let (path, args) = confirmBuildArgs()
        copyToml('test', path)
        let code = doBuild(path, args)
        if(code != 0){
            return code
        }
        var dylibPattern = ''
        for(arg in this.args where arg.startsWith('--dylibPattern=')){
            dylibPattern = arg
            break
        }
        if(dylibPattern.isEmpty()){
            throw BootException("arg --dylibPattern='...' in command line is required")
        }
        run(['run', path.toString(), dylibPattern])
    }
    private func count(dir: Path, counter: CodeCounter, ext: String, ignoreBrackets: Bool, ignoreComments: Bool): Unit {
        Directory.walk(dir){fi =>
            if (fi.isDirectory()) {
                if(fi.path.toString().contains('/src/')){
                    counter.packages++
                }
                count(fi.path, counter, ext, ignoreBrackets, ignoreComments)
            } else if (fi.path.extensionName == ext){
                counter.files++
                func count(input: InputStream){
                    let r = StringReader(input)
                    for(line in r.lines()){
                        let l = line.trimAscii()
                        if(l.size > 0 && !(ignoreBrackets && ')]}{[('.contains(l))){
                            counter.lines++
                        }
                    }
                }
                if (ignoreComments && ext == 'cj') {
                    let code = entireFileText(fi.path)
                    let tokens = cangjieLex(code)
                    try {
                        let bytes = parseProgram(tokens).toTokens().toString().unsafeBytes()
                        count(ByteBuffer(bytes))
                    } catch (e: Exception) {
                        stdOut.writeln(code)
                        e.printStackTrace()
                        count(ByteBuffer(code.unsafeBytes()))
                    }
                }else{
                    try(f = File(fi.path, Read)){
                        count(f)
                    }
                }
            } else if (fi.path.extensionName == 'toml') {
                counter.modules++
            }
            true
        }
    }
    private func count(): Int64 {
        let path = if (args.size <= 1 || args[1].startsWith('--')) {
            getWorkingDirectory()
        } else {
            Path(args[1])
        }
        var ext = 'cj'
        var ignoreBrackets = false
        var ignoreComments = false
        for (arg in args[1 ..]) {
            if (arg.startsWith('--ext=')) {
                ext = arg['--ext='.size ..]
            } else if (arg == '--ignoreBrackets') {
                ignoreBrackets = true
            } else if (arg == '--ignoreComments') {
                ignoreComments = true
            }
        }
        stdOut.writeln('path=${path};ext=${ext};ignoreBrackets=${ignoreBrackets};ignoreComments=${ignoreComments}')
        let counter = CodeCounter()
        let start = MonoTime.now()
        count(path, counter, ext, ignoreBrackets, ignoreComments)
        stdOut.writeln('modules: ${counter.modules}, packages: ${counter.packages}, files: ${counter.files}, lines: ${counter.lines}, consumes: ${MonoTime.now() - start}')
        0
    }
    private func help(): Int64 {
        let content =
'''
1.  应用项目只需要编译为动态链接库，把应用的动态链接库加入LD_LIBRARY_PATH
2.  fboot run [PATH] --dylibPattern=<DYNAMIC_LIB_NAME_REGEX_WITHOUT_EXTNAME>
3.  fboot shutdown <PID>
4.  fboot restart <PID> [PATH] --dylibPattern=<DYNAMIC_LIB_NAME_REGEX_WITHOUT_EXTNAME>
5.  fboot workspace 将当前目录初始化为仓颉workspace
6.  fboot workspace <spacename> 在当前目录创建名为<spacename>的子目录，并将它初始化为仓颉workspace
7.  fboot workspace <direct_path> 将绝对路径创建为仓颉workspace
8.  fboot module 将当前目录初始化为仓颉dynamic项目
9.  fboot module <module_name> 在当前目录创建名为<module_name>的子目录，并初始化为仓颉dynamic模块，并把模块加入当前目录的cjpm.toml
10. fboot build 编译使用fountain开发的应用项目
11. fboot count 数当前目录的仓颉代码模块数、包数、文件数、行数、计数耗时
==============下面的命令用来管理fountain本身===================
12. fboot version x.y.z 用指定版本号替换cjpm.toml和App.cj的版本号，并提交且推送当前全部修改
    - fboot version x.y.z
    - fboot version x.y.z '提交的内容'，以指定内容执行git commit
    - fboot version x.y.z tag，除了替换版本号，还会用指定的版本号创建tag：release-x.y.z
    - fboot version x.y.z tag '版本消息'，除了替换版本号，还会以'版本消息'创建附注tag
    - fboot version x.y.z '提交的内容' tag
    - fboot version x.y.z '提交的内容' tag '版本消息'
13. fboot version 显示当前fountain版本号
14. fboot help 显示命令列表
'''
        stdOut.writeln(content)
        0
    }

    public func boot(): Int64 {
        match (args[0]) {
            case 'run' => run()
            case 'shutdown' => shutdown()
            case 'restart' => restart()
            case 'module' => initModule()
            case 'workspace' => initWorkspace()
            case 'cleanUpdate' => cleanUpdate()
            case 'build' => build()
            case 'test' => test()
            case 'count' => count()
            case 'version' => version()
            case 'help' => help()
            case _ => throw BootException(
                    'first command arg must be run|shutdow|restart|module|workspace|cleanUpdate|build|count|version, but current args are ${args}')
        }
    }
}
private class CodeCounter{
    var modules = 0
    var packages = 0
    var files = 0
    var lines = 0
}