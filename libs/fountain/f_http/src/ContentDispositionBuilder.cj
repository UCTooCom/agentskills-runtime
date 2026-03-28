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
package f_http

public class ContentDispositionBuilder {
    ContentDispositionBuilder(private let cd: ContentDisposition) {}

    public prop attachment: ContentDispositionBuilder {
        get() {
            cd.setType(ContentDispositionType.attachment)
            this
        }
    }
    public prop inline: ContentDispositionBuilder {
        get() {
            cd.setType(ContentDispositionType.inline)
            this
        }
    }
    public prop formData: ContentDispositionBuilder {
        get() {
            cd.setType(ContentDispositionType.formData)
            this
        }
    }
    public func name(value: String): ContentDispositionBuilder {
        cd.setName(value)
        this
    }
    public func filename(value: String): ContentDispositionBuilder {
        cd.setFilename(value)
        this
    }
    public func size(value: Int64): ContentDispositionBuilder {
        cd.setSize(value)
        this
    }
    public func creationDate(value: DateTime): ContentDispositionBuilder {
        cd.setCreationDate(value)
        this
    }
    public func creationDate(value: String): ContentDispositionBuilder {
        cd.setCreationDate(value)
        this
    }
    public func modificationDate(value: String): ContentDispositionBuilder {
        cd.setModificationDate(value)
        this
    }
    public func readDate(value: String): ContentDispositionBuilder {
        cd.setReadDate(value)
        this
    }

    public func modificationDate(value: DateTime): ContentDispositionBuilder {
        cd.setModificationDate(value)
        this
    }
    public func readDate(value: DateTime): ContentDispositionBuilder {
        cd.setReadDate(value)
        this
    }
    public func build(): ContentDisposition {
        cd
    }
}
