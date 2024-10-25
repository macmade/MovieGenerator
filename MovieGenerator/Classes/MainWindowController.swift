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

import Cocoa
import UniformTypeIdentifiers

@objc
public class MainWindowController: NSWindowController, NSWindowDelegate
{
    @objc private dynamic var title:         String?
    @objc private dynamic var subtitle:      String?
    @objc private dynamic var icon:          NSImage?
    @objc private dynamic var sourceFolder:  URL?
    @objc private dynamic var selectedCodec: Codec?
    @objc private dynamic var selectedType:  FileType?
    @objc private dynamic var images       = [ URL ]()
    @objc private dynamic var codecs       = [ Codec ]()
    @objc private dynamic var types        = [ FileType ]()
    @objc private dynamic var width        = 0
    @objc private dynamic var height       = 0
    @objc private dynamic var fps          = 24
    @objc private dynamic var loading      = false

    public var onClose: ( () -> Void )?

    public init()
    {
        super.init( window: nil )
    }

    public required init?( coder: NSCoder )
    {
        nil
    }

    public override var windowNibName: NSNib.Name?
    {
        "MainWindowController"
    }

    public override func windowDidLoad()
    {
        super.windowDidLoad()
        self.reset()
    }

    @IBAction
    public func chooseSourceFolder( _ sender: Any? )
    {
        guard let window = self.window
        else
        {
            NSSound.beep()

            return
        }

        let panel                     = NSOpenPanel()
        panel.canChooseFiles          = false
        panel.canChooseDirectories    = true
        panel.allowsMultipleSelection = false

        panel.beginSheetModal( for: window )
        {
            guard $0 == .OK, let url = panel.url
            else
            {
                return
            }

            self.chooseSourceFolder( url: url )
        }
    }

    private func chooseSourceFolder( url: URL )
    {
        guard let enumrator = FileManager.default.enumerator( atPath: url.path( percentEncoded: false ) )
        else
        {
            self.showError( message: "Cannot read the selected folder.", closeWindow: false )

            return
        }

        let images: [ URL ] = enumrator.compactMap
        {
            enumrator.skipDescendants()

            guard let filename = $0 as? String
            else
            {
                return nil
            }

            let file = url.appending( path: filename )
            let type = UTType( filenameExtension: file.pathExtension )

            if type?.conforms( to: .image ) ?? false
            {
                return file
            }

            return nil
        }
        .sorted
        {
            $0.lastPathComponent < $1.lastPathComponent
        }

        if images.isEmpty
        {
            self.showError( message: "The selected folder does not contain any image.", closeWindow: false )

            return
        }

        self.reset()

        self.sourceFolder = url
        self.images       = images
        self.icon         = NSWorkspace.shared.icon( forFile: url.path( percentEncoded: false ) )
        self.title        = url.lastPathComponent
        self.subtitle     = images.count == 1 ? "1 Image" : "\( images.count ) Images"

        if let image = images.first, let image = NSImage( contentsOf: image )
        {
            if self.width == 0
            {
                self.width = Int( image.size.width )
            }

            if self.height == 0
            {
                self.height = Int( image.size.height )
            }
        }
    }

    private func reset()
    {
        self.icon          = NSImage( systemSymbolName: "questionmark.circle.fill", accessibilityDescription: nil )
        self.title         = nil
        self.subtitle      = "No Source Directory Selected"
        self.sourceFolder  = nil
        self.images        = []
        self.codecs        = Codec.all
        self.selectedCodec = self.codecs.first
        self.types         = FileType.all
        self.selectedType  = self.types.first
    }

    public func windowCanBeClosed() -> Bool
    {
        guard self.loading
        else
        {
            return true
        }

        let alert             = NSAlert()
        alert.messageText     = "Operations in Progress"
        alert.informativeText = "Are you sure you really want to close this window?\n\nThis will abort all running operations."

        alert.addButton( withTitle: "Cancel" )
        alert.addButton( withTitle: "Close Anyway" )

        if alert.runModal() == .alertFirstButtonReturn
        {
            return false
        }
        else
        {
            return true
        }
    }

    public func windowShouldClose( _ sender: NSWindow ) -> Bool
    {
        self.windowCanBeClosed()
    }

    public func windowWillClose( _ notification: Notification )
    {
        self.onClose?()
    }

    private func showError( message: String, closeWindow: Bool )
    {
        DispatchQueue.main.async
        {
            let alert             = NSAlert()
            alert.messageText     = "Error"
            alert.informativeText = message

            if let window = self.window
            {
                alert.beginSheetModal( for: window )
                {
                    _ in if closeWindow
                    {
                        DispatchQueue.main.async
                        {
                            window.performClose( nil )
                        }
                    }
                }
            }
            else
            {
                alert.runModal()

                if closeWindow
                {
                    DispatchQueue.main.async
                    {
                        self.window?.performClose( nil )
                    }
                }
            }
        }
    }

    @IBAction
    private func generateMovie( _ sender: Any? )
    {
        guard let window = self.window
        else
        {
            NSSound.beep()

            return
        }

        guard let codec = self.selectedCodec
        else
        {
            self.showError( message: "No codec selected.", closeWindow: false )

            return
        }

        guard let type = self.selectedType
        else
        {
            self.showError( message: "No file type selected.", closeWindow: false )

            return
        }

        guard self.images.isEmpty == false
        else
        {
            self.showError( message: "The selected folder does not contain any image.", closeWindow: false )

            return
        }

        guard self.width > 0, self.height > 0
        else
        {
            self.showError( message: "Invalid movie dimensions.", closeWindow: false )

            return
        }

        guard self.fps > 0
        else
        {
            self.showError( message: "Invalid frame rate.", closeWindow: false )

            return
        }

        let panel                  = NSSavePanel()
        panel.canCreateDirectories = true

        if let uti = type.uti
        {
            panel.allowedContentTypes  = [ uti ]
            panel.allowsOtherFileTypes = false
        }
        else
        {
            panel.allowsOtherFileTypes = true
        }

        panel.beginSheetModal( for: window )
        {
            guard $0 == .OK, let url = panel.url
            else
            {
                return
            }

            self.generateMovie(
                images:      self.images,
                destination: url,
                size:        NSSize( width: Double( self.width ), height: Double( self.height ) ),
                fps:         UInt( self.fps ),
                codec:       codec,
                type:        type
            )
        }
    }

    private func generateMovie( images: [ URL ], destination: URL, size: NSSize, fps: UInt, codec: Codec, type: FileType )
    {
        self.loading = true

        DispatchQueue.global( qos: .userInitiated ).async
        {
            let converter = VideoGenerator( images: images, size: size, destination: destination, fps: fps, codec: codec.type, fileType: type.type )
            let success   = converter.generate()

            DispatchQueue.main.async
            {
                self.loading = false

                if success
                {
                    NSWorkspace.shared.selectFile( destination.path( percentEncoded: false ), inFileViewerRootedAtPath: "" )
                }
                else
                {
                    self.showError( message: "An error occured while generating the movie.", closeWindow: false )
                }
            }
        }
    }
}
