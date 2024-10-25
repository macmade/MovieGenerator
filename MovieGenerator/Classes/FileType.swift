/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2023, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import AVFoundation
import Foundation
import UniformTypeIdentifiers

public class FileType: NSObject
{
    static var all: [ FileType ]
    {
        [
            FileType( title: "QuickTime Movie (.mov)", type: .mov, uti: UTType( filenameExtension: "mov" ) ),
            FileType( title: "MPEG-4 Video (.m4v)",    type: .m4v, uti: UTType( filenameExtension: "m4v" ) ),
            FileType( title: "MPEG-4 (.mp4)",          type: .mp4, uti: UTType( filenameExtension: "mmp4" ) ),
        ]
    }

    @objc public dynamic var title: String
    @objc public dynamic var type:  AVFileType
    @objc public dynamic var uti:   UTType?

    public init( title: String, type: AVFileType, uti: UTType? )
    {
        self.title = title
        self.type  = type
        self.uti   = uti
    }

    public override var description: String
    {
        self.title
    }

    public override func isEqual( to object: Any? ) -> Bool
    {
        self.isEqual( object )
    }

    public override func isEqual( _ object: Any? ) -> Bool
    {
        guard let other = object as? FileType
        else
        {
            return false
        }

        return self.type == other.type
    }
}
