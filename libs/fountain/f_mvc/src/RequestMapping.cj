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
package f_mvc

public abstract class RequestMapping {
    public const RequestMapping(
        public let path!: String,
        public let method!: RequestMethod,
        public let produces!: String = 'application/json',
        public let consumes!: String = 'application/json',
        public let params!: String = '',
        public let headers!: String = '',
        public let ignoreAuth!: Bool = false,
        public let ignorePrivilege!: Bool = false
    ) {}
}

@Annotation[target: [MemberFunction]]
public class PostMapping <: RequestMapping {
    public const init(
        path!: String,
        produces!: String = 'application/json',
        consumes!: String = 'application/json',
        params!: String = '',
        headers!: String = '',
        ignoreAuth!: Bool = false,
        ignorePrivilege!: Bool = false
    ) {
        super(path: path, method: RequestMethod.POST, produces: produces, consumes: consumes, params: params,
            headers: headers, ignoreAuth: ignoreAuth, ignorePrivilege: ignorePrivilege)
    }
}

@Annotation[target: [MemberFunction]]
public class GetMapping <: RequestMapping {
    public const init(
        path!: String,
        produces!: String = 'application/json',
        consumes!: String = '',
        params!: String = '',
        headers!: String = '',
        ignoreAuth!: Bool = false,
        ignorePrivilege!: Bool = false
    ) {
        super(path: path, method: RequestMethod.GET, produces: produces, consumes: consumes, params: params,
            headers: headers, ignoreAuth: ignoreAuth, ignorePrivilege: ignorePrivilege)
    }
}

@Annotation[target: [MemberFunction]]
public class PutMapping <: RequestMapping {
    public const init(
        path!: String,
        produces!: String = 'application/json',
        consumes!: String = 'application/json',
        params!: String = '',
        headers!: String = '',
        ignoreAuth!: Bool = false,
        ignorePrivilege!: Bool = false
    ) {
        super(path: path, method: RequestMethod.PUT, produces: produces, consumes: consumes, params: params,
            headers: headers, ignoreAuth: ignoreAuth, ignorePrivilege: ignorePrivilege)
    }
}

@Annotation[target: [MemberFunction]]
public class DeleteMapping <: RequestMapping {
    public const init(
        path!: String,
        produces!: String = 'application/json',
        consumes!: String = '',
        params!: String = '',
        headers!: String = '',
        ignoreAuth!: Bool = false,
        ignorePrivilege!: Bool = false
    ) {
        super(path: path, method: RequestMethod.DELETE, produces: produces, consumes: consumes, params: params,
            headers: headers, ignoreAuth: ignoreAuth, ignorePrivilege: ignorePrivilege)
    }
}

@Annotation[target: [MemberFunction]]
public class PatchMapping <: RequestMapping {
    public const init(
        path!: String,
        produces!: String = 'application/json',
        consumes!: String = 'application/json',
        params!: String = '',
        headers!: String = '',
        ignoreAuth!: Bool = false,
        ignorePrivilege!: Bool = false
    ) {
        super(path: path, method: RequestMethod.PATCH, produces: produces, consumes: consumes, params: params,
            headers: headers, ignoreAuth: ignoreAuth, ignorePrivilege: ignorePrivilege)
    }
}
