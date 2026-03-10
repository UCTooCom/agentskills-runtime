/**
 * @file
 * This file is about  yaml document.
 */

package yaml4cj.yaml

/**
 * The class is DocumentT
 * @author changeden
 * @since 0.30.4
 */
class DocumentT {
    var nodes: Array<NodeT> = Array<NodeT>()
    var versionDirective: VersionDirectiveT = VersionDirectiveT()
    var tagDirectivesData: Array<TagDirectiveT> = Array<TagDirectiveT>()
    var tagDirectivesStart: Int64 = 0
    var tagDirectivesEnd: Int64 = 0
    var startImplicit: Int64 = 0
    var endImplicit: Int64 = 0
    var startMark: MarkT = MarkT()
    var endMark: MarkT = MarkT()
}
