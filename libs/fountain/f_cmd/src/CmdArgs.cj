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
package f_cmd

import std.collection.{HashMap, ArrayList}
import std.convert.Parsable
import std.fs.Path
import std.env
import std.process.Process
import f_base.*
import f_regex.*
import f_cmd.exception.CmdException

public class CmdArgs {
    private var args = HashMap<String, ArrayList<String>>()
    private var appName = env.getCommand()
    private var _currentWorkingDir = env.getWorkingDirectory()
    private init() {
        this(env.getCommandLine()[1..])
    }
    private init(args: Array<String>) {
        var prev = ''
        for (arg in args) {
            if (arg.startsWith("--")) {
                prev = ''
                let idxopt = arg.indexOf("=")
                if (let Some(idx) <- idxopt) {
                    let key = arg[2..idx].trimAscii()
                    let val = arg[idx + 1..].trimAscii()
                    if (let Some(l) <- this.args.get(key)) {
                        l.add(val)
                    } else {
                        let l = ArrayList<String>()
                        l.add(val)
                        this.args.add(key, l)
                    }
                } else if (let key <- arg[2..].trimAscii() && !this.args.contains(key)) {
                    this.args[key] = ArrayList<String>()
                }
            } else if (arg.startsWith("-")) {
                this.args[arg] = ArrayList<String>()
                prev = arg
            } else {
                this.args[prev].add(arg)
            }
        }
    }

    public static let instance = CmdArgs()

    public func getAllKeys(prefix: String): Array<String> {
        let list = ArrayList<String>()
        for (key in args.keys() where key.startsWith(prefix)) {
            list.add(key)
        }
        list.unsafeData()
    }
    public func contains(name: String): Bool {
        args.contains(name)
    }
    public func getArgs(name: String): Option<ArrayList<String>> {
        args.get(name)
    }
    public func getArg(name: String): Option<String> {
        if (let Some(list) <- getArgs(name)) {
            list.get(0)
        }
        None<String>
    }
    public func getAppName(): String {
        return appName
    }
    public prop currentWorkingDirectory: Path {
        get() {
            _currentWorkingDir
        }
    }
    public func getInt64Arg(name: String): Option<Int64> {
        if (let Some(v) <- getArg(name)) {
            Int64.parse(v)
        }
        None<Int64>
    }
}
