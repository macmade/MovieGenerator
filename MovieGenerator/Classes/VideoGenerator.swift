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

/*
 * Copyright Notice:
 *
 * Adapted from legacy code by Adam Jensen, published under the terms
 * of the MIT License.
 *
 * See: https://gist.github.com/acj/6ae90aa1ebb8cad6b47b#file-timelapsebuilderswift30-swift
 */

import AVFoundation
import Cocoa

class VideoGenerator
{
    private var images:           [ URL ]
    private var size:             NSSize
    private var destination:      URL
    private var fps:              Int32
    private var codec:            AVVideoCodecType
    private var fileType:         AVFileType
    private var queue:            DispatchQueue
    private var videoSettings:    [ String: Any ]
    private var bufferAttributes: [ String: Any ]

    public init( images: [ URL ], size: NSSize, destination: URL, fps: UInt, codec: AVVideoCodecType, fileType: AVFileType )
    {
        self.images      = images
        self.size        = size
        self.destination = destination
        self.fps         = Int32( fps )
        self.codec       = codec
        self.fileType    = fileType
        self.queue       = DispatchQueue( label: "com.xs-labs.Brain.VideoGenerator" )

        self.videoSettings =
            [
                AVVideoCodecKey: codec,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height,
            ]

        self.bufferAttributes =
            [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey           as String: size.width,
                kCVPixelBufferHeightKey          as String: size.height,
            ]
    }

    @discardableResult
    func generate() -> Bool
    {
        autoreleasepool
        {
            do
            {
                if FileManager.default.fileExists( atPath: self.destination.path )
                {
                    try FileManager.default.removeItem( at: self.destination )
                }

                var images  = self.images
                let group   = DispatchGroup()
                let writer  = try AVAssetWriter( outputURL: self.destination, fileType: self.fileType )
                let input   = AVAssetWriterInput( mediaType: .video, outputSettings: self.videoSettings )
                let adaptor = AVAssetWriterInputPixelBufferAdaptor( assetWriterInput: input, sourcePixelBufferAttributes: self.bufferAttributes )

                writer.add( input )

                guard writer.startWriting()
                else
                {
                    return false
                }

                writer.startSession( atSourceTime: .zero )
                group.enter()

                var time = CMTimeMake( value: 0, timescale: self.fps )

                input.requestMediaDataWhenReady( on: self.queue )
                {
                    while input.isReadyForMoreMediaData && images.isEmpty == false
                    {
                        guard let image = images.first, self.append( image: image, adaptor: adaptor, time: time )
                        else
                        {
                            input.markAsFinished()
                            group.leave()

                            break
                        }

                        images.removeFirst()

                        time = CMTimeAdd( time, CMTimeMake( value: 1, timescale: self.fps ) )
                    }

                    if images.isEmpty
                    {
                        input.markAsFinished()
                        writer.finishWriting
                        {
                            group.leave()
                        }
                    }
                }

                group.wait()

                return images.isEmpty
            }
            catch
            {
                return false
            }
        }
    }

    private func append( image url: URL, adaptor: AVAssetWriterInputPixelBufferAdaptor, time: CMTime ) -> Bool
    {
        autoreleasepool
        {
            guard let image   = NSImage( contentsOf: url ),
                  let cgImage = image.cgImage( forProposedRect: nil, context: nil, hints: nil ),
                  let pool    = adaptor.pixelBufferPool
            else
            {
                return false
            }

            var buffer: CVPixelBuffer?

            guard CVPixelBufferPoolCreatePixelBuffer( kCFAllocatorDefault, pool, &buffer ) == 0, let buffer = buffer
            else
            {
                return false
            }

            CVPixelBufferLockBaseAddress( buffer, CVPixelBufferLockFlags( rawValue: 0 ) )

            let context = CGContext(
                data:             CVPixelBufferGetBaseAddress( buffer ),
                width:            Int( image.size.width ),
                height:           Int( image.size.height ),
                bitsPerComponent: 8,
                bytesPerRow:      CVPixelBufferGetBytesPerRow( buffer ),
                space:            CGColorSpaceCreateDeviceRGB(),
                bitmapInfo:       CGImageAlphaInfo.premultipliedFirst.rawValue
            )

            guard let context = context
            else
            {
                CVPixelBufferLockBaseAddress( buffer, CVPixelBufferLockFlags( rawValue: 0 ) )

                return false
            }

            context.draw( cgImage, in: NSRect( origin: NSZeroPoint, size: image.size ) )
            CVPixelBufferUnlockBaseAddress( buffer, CVPixelBufferLockFlags( rawValue: 0 ) )

            if adaptor.append( buffer, withPresentationTime: time ) == false
            {
                return false
            }

            return true
        }
    }
}
