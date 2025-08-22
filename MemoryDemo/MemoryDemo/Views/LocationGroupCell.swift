import UIKit
import Photos
import Combine
import SnapKit

class LocationGroupCell: UICollectionViewCell {
    private var imageViews: [CustomImageView] = []
    private let mainImageView: CustomImageView = {
        let imageView = CustomImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.layer.masksToBounds = true
        imageView.backgroundColor = .systemGray6
        return imageView
    }()
    
    private let locationLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.numberOfLines = 0
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.clipsToBounds = true
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        return label
    }()
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(mainImageView)
        contentView.addSubview(locationLabel)
        contentView.addSubview(smallImagesStackView)
        
        // 创建4个小图片视图
        for _ in 0..<4 {
            let imageView = CustomImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            imageView.layer.masksToBounds = true
            imageView.backgroundColor = .systemGray6
            imageViews.append(imageView)
            smallImagesStackView.addArrangedSubview(imageView)
        }
        
        // 使用 SnapKit 设置约束
        mainImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.left.equalToSuperview().offset(4)
            make.right.equalToSuperview().offset(-4)
            make.height.equalTo(contentView.snp.height).multipliedBy(0.7)
        }
        
        smallImagesStackView.snp.makeConstraints { make in
            make.top.equalTo(mainImageView.snp.bottom).offset(4)
            make.left.equalToSuperview().offset(4)
            make.right.equalToSuperview().offset(-4)
            make.bottom.equalToSuperview().offset(-4)
        }
        
        locationLabel.snp.makeConstraints { make in
            make.edges.equalTo(mainImageView)
        }
        
    }
    
    private let geocoder = CLGeocoder()
    
    private let smallImagesStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 4
        return stackView
    }()
    
    func configure(with viewModel: LocationGroupCellViewModel) {
        if viewModel.locationText.isEmpty {
            geocoder.reverseGeocodeLocation(viewModel.locationGroup.location) { [weak self] placemarks, error in
                guard let self = self else {return}
                DispatchQueue.main.async {
                    if let placemark = placemarks?.first {
                        var components: [String] = []
                        if let country = placemark.country { components.append(country) }
                        if let administrativeArea = placemark.administrativeArea { components.append(administrativeArea) }
                        if let locality = placemark.locality { components.append(locality) }
                        if let subLocality = placemark.subLocality { components.append(subLocality) }
                        self.locationLabel.text = components.joined(separator: " ")
                        viewModel.locationText = self.locationLabel.text ?? ""
                    } else {
                        self.locationLabel.text = "未知位置"
                    }
                }
            }
        } else {
            self.locationLabel.text = viewModel.locationText
        }
        
        // 加载主图
        if let mainAsset = viewModel.locationGroup.previewAssets.first {
            mainImageView.assetID = mainAsset.localIdentifier
            mainImageView.fetchImageAsset(mainAsset, targetSize: mainImageView.frame.size, options: imageRequestOption, photoId: mainAsset.localIdentifier)
        }
        
        // 加载小图
        for (index, asset) in viewModel.locationGroup.previewAssets.dropFirst().prefix(4).enumerated() {
            let imageView = imageViews[index]
            imageView.assetID = asset.localIdentifier
            let size = imageView.frame.size
            imageView.fetchImageAsset(asset, targetSize: size, options: imageRequestOption, photoId: asset.localIdentifier)
        }
    }
    
    var imageRequestOption: PHImageRequestOptions {
        // 设置图片请求选项
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.isSynchronous = false
        return requestOptions
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        mainImageView.image = nil
        imageViews.forEach { $0.image = nil }
        locationLabel.text = nil
        if geocoder.isGeocoding {
            geocoder.cancelGeocode()
        }
    }
} 
