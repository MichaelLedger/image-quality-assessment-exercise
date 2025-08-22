import UIKit
import Photos
import Combine
import Vision
import SnapKit
import MLKitImageLabeling

class LocationGroupDetailViewController: UIViewController {
    private let viewModel: LocationGroupCellViewModel
    private var collectionView: UICollectionView!
    private var cancellables = Set<AnyCancellable>()
    private let headerHeight: CGFloat = 260
    private var isRecommendTapped = false
    private var headerView: StretchyHeaderView? = nil
    
    init(viewModel: LocationGroupCellViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupBindings() {
        viewModel.$recommendedAssets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isRecommendTapped {
                    self.collectionView.reloadData()
                }
            }
            .store(in: &cancellables)
        
        viewModel.$isProcessingComplete
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isComplete in
                guard let self = self else { return }
                self.headerView?.shouldShowRecommendLoading = !isComplete
            }
            .store(in: &cancellables)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupCollectionView()
    }
    
    private func setupNavigationBar() {
        title = "Trip Details"
    }
    
    private func setupCollectionView() {
        let layout = createLayout()
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.register(StretchyHeaderView.self,
                              forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                              withReuseIdentifier: StretchyHeaderView.reuseIdentifier)
        view.addSubview(collectionView)
        
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        let width = (view.bounds.width - 12) / 4
        layout.itemSize = CGSize(width: width, height: width)
        layout.headerReferenceSize = CGSize(width: view.bounds.width, height: headerHeight)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        return layout
    }
}

extension LocationGroupDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.locationGroup.assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let asset = viewModel.locationGroup.assets[indexPath.item]
        cell.configure(with: asset)
        if isRecommendTapped {
            cell.checkmarkImageView.isHidden = !viewModel.recommendedAssets.contains(asset)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                           withReuseIdentifier: StretchyHeaderView.reuseIdentifier,
                                                                           for: indexPath) as! StretchyHeaderView
            if let firstAsset = viewModel.locationGroup.assets.first,
               let lastAsset = viewModel.locationGroup.assets.last {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM dd, yyyy"
                
                let dateStr = "\(dateFormatter.string(from: firstAsset.creationDate ?? Date())) - \(dateFormatter.string(from: lastAsset.creationDate ?? Date()))"
                
                headerView.configure(
                    with: firstAsset,
                    title: viewModel.locationText,
                    date: dateStr,
                    photoCount: viewModel.locationGroup.assets.count
                )
                headerView.shouldShowRecommendLoading = !viewModel.isProcessingComplete
                headerView.delegate = self
                self.headerView = headerView
            }
            return headerView
        }
        return UICollectionReusableView()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y
        if offset < 0 {
            if let headerView = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) {
                headerView.frame.size.height = max(abs(offset) + headerHeight, headerHeight)
                headerView.frame.origin.y = offset
            }
        }
    }
}

extension LocationGroupDetailViewController: StretchyHeaderViewDelegate {
    func headerView(_ headerView: StretchyHeaderView, didTapRecommendButton button: UIButton) {
        isRecommendTapped = true
        self.collectionView.reloadData()
    }
    
    func headerView(_ headerView: StretchyHeaderView, didTapSelectAllButton button: UIButton) {
        // 处理全选按钮点击事件
        print("全选按钮被点击")
    }
}
