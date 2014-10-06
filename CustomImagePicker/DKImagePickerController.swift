//
//  DKImagePickerController.swift
//  CustomImagePicker
//
//  Created by ZhangAo on 14-10-2.
//  Copyright (c) 2014年 ZhangAo. All rights reserved.
//

import UIKit
import AssetsLibrary

// Cell Identifier
let GroupCellIdentifier = "GroupCellIdentifier"
let ImageCellIdentifier = "ImageCellIdentifier"

// Nofifications
let DKImageSelectedNotification = "DKImageSelectedNotification"
let DKImageUnselectedNotification = "DKImageUnselectedNotification"

// Group Model
class DKAssetGroup : NSObject {
    var groupName: NSString!
    var thumbnail: UIImage!
    var group: ALAssetsGroup!
}

// Asset Model
class DKAsset: NSObject {
    var thumbnailImage: UIImage?
    var originalImage: UIImage?
    var url: NSURL?
    
    override func isEqual(object: AnyObject?) -> Bool {
        let other = object as DKAsset!
        return self.url!.isEqual(other.url!)
    }
}

protocol DKImagePickerControllerDelegate : NSObjectProtocol {
    func imagePickerControllerDidSelectedAssets(images: [DKAsset]!)
    func imagePickerControllerCancelled()
}

extension UIViewController {
    var imagePickerController: DKImagePickerController? {
        get {
            let nav = self.navigationController
            if nav is DKImagePickerController {
                return nav as? DKImagePickerController
            } else {
                return nil
            }
        }
    }
}

class DKImageGroupViewController: UICollectionViewController {
    
    class DKImageCollectionCell: UICollectionViewCell {
        var thumbnail: UIImage! {
            didSet {
                self.imageView.image = thumbnail
            }
        }
        
        override var selected: Bool {
            get {
                return super.selected
            }
            set {
                super.selected = newValue
                checkView.hidden = !super.selected
            }
        }
        
        private var imageView = UIImageView()
        private var checkView = UIImageView(image: UIImage(named: "photo_checked"))
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            imageView.frame = self.bounds
            self.contentView.addSubview(imageView)
            self.contentView.addSubview(checkView)
        }
        
        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            imageView.frame = self.bounds
            checkView.frame.origin = CGPoint(x: self.contentView.bounds.width - checkView.bounds.width,
                y: 0)
        }
    }
    
    var assetGroup: DKAssetGroup!
    private lazy var imageAssets: NSMutableArray = {
        return NSMutableArray()
    }()
    
    override init() {
        let layout = UICollectionViewFlowLayout()
        
        let interval: CGFloat = 3
        layout.minimumInteritemSpacing = interval
        layout.minimumLineSpacing = interval
        
        let screenWidth = UIScreen.mainScreen().bounds.width
        let itemWidth = (screenWidth - interval * 3) / 4
        
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        super.init(collectionViewLayout: layout)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        assert(assetGroup != nil, "assetGroup is nil")

        self.title = assetGroup.groupName
        
        self.collectionView?.backgroundColor = UIColor.whiteColor()
        self.collectionView?.allowsMultipleSelection = true
        self.collectionView?.registerClass(DKImageCollectionCell.self, forCellWithReuseIdentifier: ImageCellIdentifier)
        
        assetGroup.group.enumerateAssetsUsingBlock {[unowned self](result: ALAsset!, index: Int, stop: UnsafeMutablePointer<ObjCBool>) in
            if result != nil {
                let asset = DKAsset()
                asset.thumbnailImage = UIImage(CGImage:result.thumbnail().takeUnretainedValue())
                asset.url = result.valueForProperty(ALAssetPropertyAssetURL) as? NSURL
                self.imageAssets.addObject(asset)
            } else {
                self.collectionView!.reloadData()
                dispatch_async(dispatch_get_main_queue()) {
                    self.collectionView!.scrollToItemAtIndexPath(NSIndexPath(forRow: self.imageAssets.count-1, inSection: 0),
                        atScrollPosition: UICollectionViewScrollPosition.Bottom,
                        animated: false)
                }
            }
        }
    }
    
    //Mark: - UICollectionViewDelegate, UICollectionViewDataSource methods
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageAssets.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(ImageCellIdentifier, forIndexPath: indexPath) as DKImageCollectionCell
        
        let asset = imageAssets[indexPath.row] as DKAsset
        cell.thumbnail = asset.thumbnailImage
        
        if find(self.imagePickerController!.selectedAssets, asset) != nil {
            cell.selected = true
        } else {
            cell.selected = false
        }
        
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        NSNotificationCenter.defaultCenter().postNotificationName(DKImageSelectedNotification, object: imageAssets[indexPath.row])
    }
    
    override func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        NSNotificationCenter.defaultCenter().postNotificationName(DKImageUnselectedNotification, object: imageAssets[indexPath.row])
    }
}

class DKAssetsLibraryController: UITableViewController {
    
    lazy var groups: NSMutableArray = {
        return NSMutableArray()
    }()
    
    lazy var library: ALAssetsLibrary = {
        return ALAssetsLibrary()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: GroupCellIdentifier)
        self.view.backgroundColor = UIColor.whiteColor()
        
        library.enumerateGroupsWithTypes(0xFFFFFFFF, usingBlock: {(group: ALAssetsGroup! , stop: UnsafeMutablePointer<ObjCBool>) in
            if group != nil {
                if group.numberOfAssets() != 0 {
                    let groupName = group.valueForProperty(ALAssetsGroupPropertyName) as NSString
                    
                    let assetGroup = DKAssetGroup()
                    assetGroup.groupName = groupName
                    assetGroup.thumbnail = UIImage(CGImage: group.posterImage().takeUnretainedValue())
                    assetGroup.group = group
                    self.groups.insertObject(assetGroup, atIndex: 0)
                }
            } else {
                self.tableView.reloadData()
            }
        }, failureBlock: {(error: NSError!) in
                println(error.localizedDescription)
        })
    }
    
    // MARK: - UITableViewDelegate, UITableViewDataSource methods
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(GroupCellIdentifier, forIndexPath: indexPath) as UITableViewCell
        
        let assetGroup = groups[indexPath.row] as DKAssetGroup
        cell.textLabel?.text = assetGroup.groupName
        cell.imageView?.image = assetGroup.thumbnail
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        let assetGroup = groups[indexPath.row] as DKAssetGroup
        let imageGroupController = DKImageGroupViewController()
        imageGroupController.assetGroup = assetGroup
        self.navigationController?.pushViewController(imageGroupController, animated: true)
    }
}

class DKImagePickerController: UINavigationController {
    
    let previewHeight: CGFloat = 80
    
    class DKPreviewView: UIScrollView {
        let interval: CGFloat = 5
        private var imageLengthOfSide: CGFloat!
        private var imageViews = [UIImageView]()
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            imageLengthOfSide = self.bounds.height - interval * 2
        }
        
        func imageFrameForIndex(index: Int) -> CGRect {
            return CGRect(x: CGFloat(index) * imageLengthOfSide + CGFloat(index + 1) * interval,
                y: (self.bounds.height - imageLengthOfSide)/2,
                width: imageLengthOfSide, height: imageLengthOfSide)
        }
        
        func insertImage(image: UIImage) {
            let imageView = UIImageView(image: image)
            imageView.frame = imageFrameForIndex(imageViews.count)
            
            self.addSubview(imageView)
            imageViews.append(imageView)
            setupContent(true)
        }
        
        func removeImage(image: UIImage) {
            for (index,imageView) in enumerate(imageViews) {
                if image == imageView.image {
                    imageView.removeFromSuperview()
                    imageViews.removeAtIndex(index)
                    
                    setupContent(false)
                    break;
                }
            }
        }
        
        private func setupContent(isInsert: Bool) {
            if isInsert == false {
                for (index,imageView) in enumerate(imageViews) {
                    imageView.frame = imageFrameForIndex(index)
                }
            }
            self.contentSize = CGSize(width: CGRectGetMaxX((self.subviews.last as UIView).frame) + interval,
                height: self.bounds.height)
        }
    }
    
    class DKContentWrapperViewController: UIViewController {
        var contentViewController: UIViewController
        var bottomBarHeight: CGFloat = 0
        var showBottomBar: Bool = false {
            didSet {
                if self.showBottomBar {
                    self.contentViewController.view.frame.size.height = self.view.bounds.size.height - self.bottomBarHeight
                } else {
                    self.contentViewController.view.frame.size.height = self.view.bounds.size.height
                }
            }
        }
        
        init(_ viewController: UIViewController) {
            contentViewController = viewController

            super.init(nibName: nil, bundle: nil)
            self.addChildViewController(viewController)
            
            contentViewController.addObserver(self, forKeyPath: "title", options: NSKeyValueObservingOptions.New, context: nil)
        }
        
        deinit {
            contentViewController.removeObserver(self, forKeyPath: "title")
        }

        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
            if keyPath == "title" {
                self.title = contentViewController.title
            }
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            self.view.backgroundColor = UIColor.whiteColor()
            self.view.addSubview(contentViewController.view)
            contentViewController.view.frame = view.bounds
        }
    }
    
    var selectedAssets: [DKAsset]!
    weak var pickerDelegate: DKImagePickerControllerDelegate?
    lazy private var imagesPreviewView: DKPreviewView = {
        let preview = DKPreviewView()
        preview.hidden = true
        preview.backgroundColor = UIColor.lightGrayColor()
        return preview
    }()
    lazy private var doneButton: UIButton =  {
        let button = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
        button.setTitle("", forState: UIControlState.Normal)
        button.setTitleColor(self.navigationBar.tintColor, forState: UIControlState.Normal)
        button.reversesTitleShadowWhenHighlighted = true
        button.addTarget(self, action: "onDoneClicked", forControlEvents: UIControlEvents.TouchUpInside)
        return button
    }()
    
    convenience override init() {
        var libraryController = DKAssetsLibraryController()
        var wrapperVC = DKContentWrapperViewController(libraryController)
        self.init(rootViewController: wrapperVC)
        wrapperVC.bottomBarHeight = previewHeight

        selectedAssets = [DKAsset]()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagesPreviewView.frame = CGRect(x: 0, y: view.bounds.height - previewHeight, width: view.bounds.width, height: previewHeight)
        imagesPreviewView.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleTopMargin
        
        view.addSubview(imagesPreviewView)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "selectedImage:", name: DKImageSelectedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "unselectedImage:", name: DKImageUnselectedNotification, object: nil)
    }

    override func pushViewController(viewController: UIViewController, animated: Bool) {
        var wrapperVC = DKContentWrapperViewController(viewController)
        wrapperVC.bottomBarHeight = previewHeight
        wrapperVC.showBottomBar = !imagesPreviewView.hidden

        super.pushViewController(wrapperVC, animated: animated)

        self.topViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.doneButton)
        
        if self.viewControllers.count == 1 && self.topViewController?.navigationItem.leftBarButtonItem == nil {
            self.topViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Cancel,
                target: self,
                action: "onCancelClicked")
        }
    }
    
    // MARK: - Delegate methods
    
    func onCancelClicked() {
        if let delegate = self.pickerDelegate {
            delegate.imagePickerControllerCancelled()
        }
    }
    
    func onDoneClicked() {
        if let delegate = self.pickerDelegate {
            delegate.imagePickerControllerDidSelectedAssets(self.selectedAssets)
        }
    }
    
    // MARK: - Notifications
    func selectedImage(noti: NSNotification) {
        if let asset = noti.object as? DKAsset {
            selectedAssets.append(asset)
            imagesPreviewView.insertImage(asset.thumbnailImage!)
            imagesPreviewView.hidden = false
            
            (self.viewControllers as [DKContentWrapperViewController]).map {$0.showBottomBar = !self.imagesPreviewView.hidden}
            self.doneButton.setTitle("确定(\(selectedAssets.count))", forState: UIControlState.Normal)
            self.doneButton.sizeToFit()
        }
    }
    
    func unselectedImage(noti: NSNotification) {
        if let asset = noti.object as? DKAsset {
            selectedAssets.removeAtIndex(find(selectedAssets, asset)!)
            imagesPreviewView.removeImage(asset.thumbnailImage!)
            
            self.doneButton.setTitle("确定(\(selectedAssets.count))", forState: UIControlState.Normal)
            self.doneButton.sizeToFit()
            if selectedAssets.count <= 0 {
                imagesPreviewView.hidden = true
                
                (self.viewControllers as [DKContentWrapperViewController]).map {$0.showBottomBar = !self.imagesPreviewView.hidden}
                self.doneButton.setTitle("", forState: UIControlState.Normal)
            }
        }
    }
}
