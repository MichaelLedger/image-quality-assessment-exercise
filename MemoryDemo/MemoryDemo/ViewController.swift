import UIKit
import Photos
import Vision
import CoreImage
import CoreLocation
import SnapKit
import Combine

// MARK: - Views
class ViewController: UIViewController {
    private let viewModel = LocationGroupViewModel()
    private var collectionView: UICollectionView!
    private var cancellables = Set<AnyCancellable>()
    private let segmentedControl: UISegmentedControl = {
        let items = ["Moment", "Location"]
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0 // 默认选中Location
        segmentedControl.backgroundColor = .systemBackground
        if #available(iOS 13.0, *) {
            segmentedControl.selectedSegmentTintColor = .systemBlue
        }
        return segmentedControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupCollectionView()
        setupBindings()
        requestPhotoLibraryAccessAndStart()
    }
    
    private func setupNavigationBar() {
        view.backgroundColor = .white
        
        // 设置导航栏标题视图
        navigationItem.titleView = segmentedControl
        
        // 添加分段控制器事件处理
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
    }
    
    @objc private func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0: // Moment
            self.viewModel.getPhotoLibraryMoments()
        case 1: // Location
            self.viewModel.analyzePhotosByDistance()
        default:
            break
        }
    }
    
    private func setupBindings() {
        viewModel.$locationGroups
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 20
        let width = (view.bounds.width - 20.0)
        layout.itemSize = CGSize(width: width, height: 300)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(LocationGroupCell.self, forCellWithReuseIdentifier: "LocationGroupCell")
        view.addSubview(collectionView)
        
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }
    
    func requestPhotoLibraryAccessAndStart() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self,
                  status == .authorized || status == .limited else {
                print("权限拒绝")
                return
            }
            DispatchQueue.main.async {
                if self.segmentedControl.selectedSegmentIndex == 0 {
                    self.viewModel.getPhotoLibraryMoments()
                } else {
                    self.viewModel.analyzePhotosByDistance()
                }
            }
        }
    }
}

extension ViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.locationGroups.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocationGroupCell", for: indexPath) as! LocationGroupCell
        let cellViewModel = viewModel.locationGroups[indexPath.item]
        cell.configure(with: cellViewModel)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cellViewModel = viewModel.locationGroups[indexPath.item]
        let detailVC = LocationGroupDetailViewController(viewModel: cellViewModel)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
