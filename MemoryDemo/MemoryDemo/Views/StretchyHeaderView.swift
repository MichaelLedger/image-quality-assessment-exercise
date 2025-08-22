import UIKit
import Photos
import SnapKit

protocol StretchyHeaderViewDelegate: AnyObject {
    func headerView(_ headerView: StretchyHeaderView, didTapRecommendButton button: UIButton)
    func headerView(_ headerView: StretchyHeaderView, didTapSelectAllButton button: UIButton)
}

class StretchyHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "StretchyHeaderView"
    
    weak var delegate: StretchyHeaderViewDelegate?
    
    private let imageView: CustomImageView = {
        let imageView = CustomImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let gradientView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.numberOfLines = 0
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 13)
        return label
    }()
    
    private let photoCountView: UIView = {
        let view = UIView()
        return view
    }()
    
    private let photoCountImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "photo.fill")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let photoCountLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 13)
        return label
    }()
    
    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private let selectAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 15
        button.setTitle("Select All", for: .normal)
        button.setImage(UIImage(systemName: "photo.fill"), for: .normal)
        button.tintColor = .black
        button.titleLabel?.font = .systemFont(ofSize: 13)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        return button
    }()
    
    private let selectRecommendedButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 15
        button.setTitle("Select Recommended", for: .normal)
        button.setImage(UIImage(systemName: "star.fill"), for: .normal)
        button.setTitle("", for: .disabled)
        button.setImage(UIImage(), for: .disabled)
        button.tintColor = .black
        button.titleLabel?.font = .systemFont(ofSize: 13)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        return button
    }()
    
    private let activityIndicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        view.tintColor = .lightGray
        return view
    }()
    
    private let bottomDateView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()
    
    private let bottomDateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17)
        label.textColor = .black
        return label
    }()
    
    private let bottomSelectAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select All", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        [imageView, gradientView, titleLabel, dateLabel, photoCountView, buttonStackView, bottomDateView].forEach {
            addSubview($0)
        }
        
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(dateLabel.snp.top).offset(-8)
        }
        
        dateLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.bottom.equalTo(buttonStackView.snp.top).offset(-16)
        }
        
        [photoCountImageView, photoCountLabel].forEach {
            photoCountView.addSubview($0)
        }
        
        photoCountImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
        }
        
        photoCountLabel.snp.makeConstraints { make in
            make.left.equalTo(photoCountImageView.snp.right).offset(4)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
        }
        
        photoCountView.snp.makeConstraints { make in
            make.left.equalTo(dateLabel.snp.right).offset(16)
            make.centerY.equalTo(dateLabel)
        }
        
        buttonStackView.addArrangedSubview(selectAllButton)
        buttonStackView.addArrangedSubview(selectRecommendedButton)
        
        selectRecommendedButton.addSubview(activityIndicatorView)
        
        activityIndicatorView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 40, height: 40))
        }
        
        buttonStackView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(bottomDateView.snp.top).offset(-16)
            make.height.equalTo(30)
        }
        
        // 设置底部日期视图
        [bottomDateLabel, bottomSelectAllButton].forEach {
            bottomDateView.addSubview($0)
        }
        
        bottomDateView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(44)
        }
        
        bottomDateLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        
        bottomSelectAllButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        
        // 添加顶部分割线
        let separator = UIView()
        separator.backgroundColor = .separator
        bottomDateView.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.left.top.right.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }
    }
    
    private func setupActions() {
        selectRecommendedButton.addTarget(self, action: #selector(recommendButtonTapped), for: .touchUpInside)
        selectAllButton.addTarget(self, action: #selector(selectAllButtonTapped), for: .touchUpInside)
        bottomSelectAllButton.addTarget(self, action: #selector(selectAllButtonTapped), for: .touchUpInside)
    }
    
    @objc private func recommendButtonTapped() {
        delegate?.headerView(self, didTapRecommendButton: selectRecommendedButton)
    }
    
    @objc private func selectAllButtonTapped(_ button: UIButton) {
        delegate?.headerView(self, didTapSelectAllButton: button)
    }
    
    var shouldShowRecommendLoading: Bool = true {
        didSet {
            if shouldShowRecommendLoading {
                activityIndicatorView.startAnimating()
            } else {
                activityIndicatorView.stopAnimating()
            }
            activityIndicatorView.isHidden = !shouldShowRecommendLoading
            selectRecommendedButton.isEnabled = !shouldShowRecommendLoading
        }
    }
    
    func configure(with asset: PHAsset, title: String, date: String, photoCount: Int) {
        imageView.assetID = asset.localIdentifier
        imageView.fetchImageAsset(asset, targetSize: frame.size, photoId: asset.localIdentifier)
        
        titleLabel.text = title
        dateLabel.text = date
        photoCountLabel.text = "\(photoCount)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        bottomDateLabel.text = "\(dateFormatter.string(from: asset.creationDate ?? Date())) (\(photoCount) Photos)"
    }
} 
