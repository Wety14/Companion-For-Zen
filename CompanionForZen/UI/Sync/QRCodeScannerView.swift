import SwiftUI
import AVFoundation

/// Fullscreen camera QR code scanner view for pairing with Zen Browser / Firefox Desktop.
public struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ZenThemeManager.shared
    
    public var onCodeScanned: (String) -> Void
    
    @State private var isTorchOn: Bool = false
    @State private var hasCameraAccess: Bool = true
    @State private var isCameraAvailable: Bool = true
    @State private var isProcessingCode: Bool = false
    @State private var scanLineOffset: CGFloat = 0
    
    public init(onCodeScanned: @escaping (String) -> Void) {
        self.onCodeScanned = onCodeScanned
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isCameraAvailable && hasCameraAccess {
                    // Live camera preview layer
                    QRCameraPreviewRepresentable(
                        isTorchOn: isTorchOn,
                        onDetectedCode: { code in
                            handleDetectedCode(code)
                        }
                    )
                    .ignoresSafeArea()
                    
                    // Unified Viewfinder and aligned laser scan bar
                    GeometryReader { geo in
                        let size = min(geo.size.width * 0.72, 280)
                        let rect = CGRect(
                            x: (geo.size.width - size) / 2,
                            y: (geo.size.height - size) / 2,
                            width: size,
                            height: size
                        )
                        let travelDistance = size / 2 - 14
                        
                        ZStack {
                            // Darkened vignette outside cutout
                            QRHoleShape(cutout: rect)
                                .fill(Color.black.opacity(0.60), style: FillStyle(eoFill: true))
                                .ignoresSafeArea()
                            
                            // Perfectly concentric viewfinder container
                            ZStack {
                                // Light gray frame border
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                                
                                // Glowing corner guides
                                QRViewfinderCorners(size: size, color: themeManager.accentColor)
                                
                                // Laser beam scanning animation (aligned with the exact frame)
                                if !isProcessingCode {
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    themeManager.accentColor.opacity(0),
                                                    themeManager.accentColor,
                                                    themeManager.accentColor.opacity(0)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: size - 24, height: 2.5)
                                        .shadow(color: themeManager.accentColor, radius: 8, x: 0, y: 0)
                                        .offset(y: scanLineOffset)
                                        .onAppear {
                                            scanLineOffset = -travelDistance
                                            withAnimation(
                                                .easeInOut(duration: 1.8)
                                                .repeatForever(autoreverses: true)
                                            ) {
                                                scanLineOffset = travelDistance
                                            }
                                        }
                                }
                            }
                            .frame(width: size, height: size)
                            .position(x: rect.midX, y: rect.midY)
                        }
                    }
                    .ignoresSafeArea()
                } else if !isCameraAvailable {
                    // Simulator fallback UI
                    VStack(spacing: 24) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(themeManager.accentColor.opacity(0.12))
                                .frame(width: 90, height: 90)
                            
                            Image(systemName: "qrcode")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundColor(themeManager.accentColor)
                        }
                        
                        VStack(spacing: 8) {
                            Text(String(localized: "simulator_mode", bundle: .main))
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                            
                            Text("no_camera_simulator")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        Button {
                            Haptics.medium()
                            handleDetectedCode("https://accounts.firefox.com/pair?channel=zen-mac-pro-9988&key=demo-key")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "qrcode.viewfinder")
                                Text(String(localized: "simulate_pairing", bundle: .main))
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(themeManager.accentColor.gradient)
                            .clipShape(Capsule())
                        }
                    }
                    .padding()
                } else {
                    // Camera permission denied UI
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("camera_access_required")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("qr_camera_permission_desc")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        
                        Button(String(localized: "open_settings", bundle: .main)) {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .padding()
                }
                
                // Spinner overlay while pairing
                if isProcessingCode {
                    ZStack {
                        Color.black.opacity(0.75).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.3)
                            Text("connecting_to_zen")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(28)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
            .navigationTitle(String(localized: "qr_code_login", bundle: .main))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel", bundle: .main)) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isCameraAvailable && hasCameraAccess {
                        Button {
                            Haptics.light()
                            isTorchOn.toggle()
                        } label: {
                            Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(isTorchOn ? .yellow : .white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.2), in: Circle())
                        }
                    }
                }
            }
            .onAppear {
                checkCameraPermission()
            }
        }
    }
    
    private func checkCameraPermission() {
        guard AVCaptureDevice.default(for: .video) != nil else {
            isCameraAvailable = false
            return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraAccess = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    hasCameraAccess = granted
                }
            }
        case .denied, .restricted:
            hasCameraAccess = false
        @unknown default:
            hasCameraAccess = false
        }
    }
    
    private func handleDetectedCode(_ code: String) {
        guard !isProcessingCode else { return }
        isProcessingCode = true
        Haptics.success()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onCodeScanned(code)
            dismiss()
        }
    }
}

// MARK: - Viewfinder Geometry & Corner Reticles

private struct QRHoleShape: Shape {
    let cutout: CGRect
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(in: cutout, cornerSize: CGSize(width: 22, height: 22))
        return path
    }
}

private struct QRViewfinderCorners: View {
    let size: CGFloat
    let color: Color
    let cornerLength: CGFloat = 26
    let strokeWidth: CGFloat = 3.5
    
    var body: some View {
        Canvas { context, _ in
            let r = CGRect(x: 0, y: 0, width: size, height: size)
            let cl = cornerLength
            
            var p = Path()
            // Top Left
            p.move(to: CGPoint(x: r.minX, y: r.minY + cl))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + 12))
            p.addQuadCurve(to: CGPoint(x: r.minX + 12, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + cl, y: r.minY))
            
            // Top Right
            p.move(to: CGPoint(x: r.maxX - cl, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - 12, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + 12), control: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + cl))
            
            // Bottom Right
            p.move(to: CGPoint(x: r.maxX, y: r.maxY - cl))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 12))
            p.addQuadCurve(to: CGPoint(x: r.maxX - 12, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cl))
            
            // Bottom Left
            p.move(to: CGPoint(x: r.minX + cl, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + 12, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 12), control: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - cl))
            
            context.stroke(p, with: .color(color), lineWidth: strokeWidth)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - UIKit AVCapture Video Representable

private struct QRCameraPreviewRepresentable: UIViewControllerRepresentable {
    var isTorchOn: Bool
    var onDetectedCode: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCodeScanned = onDetectedCode
        return vc
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        uiViewController.setTorch(on: isTorchOn)
    }
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didCaptureCode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        didCaptureCode = false
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
            }
        }
        setTorch(on: false)
    }
    
    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Torch unavailable
        }
    }
    
    private func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                return
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                return
            }
            
            let preview = AVCaptureVideoPreviewLayer(session: captureSession)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.layer.bounds
            view.layer.addSublayer(preview)
            self.previewLayer = preview
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        } catch {
            // Camera input failure
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didCaptureCode,
              let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue,
              !stringValue.isEmpty else {
            return
        }
        
        didCaptureCode = true
        onCodeScanned?(stringValue)
    }
}
