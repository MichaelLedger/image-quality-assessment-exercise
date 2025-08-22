//
//  PhotoCell.swift
//  MemoryDemo
//
//
import UIKit
import Foundation
import Photos
import SnapKit

class PhotoCell: UICollectionViewCell {
    private let imageView: CustomImageView = {
        let imageView = CustomImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.addSubview(checkmarkImageView)
        checkmarkImageView.snp.makeConstraints { make in
            make.top.right.equalToSuperview().inset(8)
            make.width.height.equalTo(24)
        }
    }
    
    func configure(with asset: PHAsset) {
        imageView.assetID = asset.localIdentifier
        imageView.fetchImageAsset(asset, targetSize: frame.size, photoId: asset.localIdentifier)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        checkmarkImageView.isHidden = true
    }
}
