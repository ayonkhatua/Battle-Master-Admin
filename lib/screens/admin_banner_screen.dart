import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminBannerScreen extends StatefulWidget {
  const AdminBannerScreen({super.key});

  @override
  State<AdminBannerScreen> createState() => _AdminBannerScreenState();
}

class _AdminBannerScreenState extends State<AdminBannerScreen> {
  bool _isUploading = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  List<Map<String, dynamic>> _banners = [];
  bool _isLoadingBanners = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  // Fetch existing banners
  Future<void> _fetchBanners() async {
    setState(() => _isLoadingBanners = true);
    try {
      final response = await Supabase.instance.client
          .from('app_banners')
          .select()
          .order('id', ascending: false);
      setState(() {
        _banners = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching banners: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBanners = false);
    }
  }

  // Function to pick an image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compresses image to save storage
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Function to upload image to Supabase Storage
  Future<void> _uploadImage() async {
    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Extract extension and create a unique file name
      final fileExtension =
          (_selectedImageName != null && _selectedImageName!.contains('.'))
          ? _selectedImageName!.split('.').last
          : 'jpg';
      final fileName =
          'banner_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final filePath = 'uploads/$fileName';

      // Uploading binary data to Supabase Storage bucket
      await Supabase.instance.client.storage
          .from('Battle Master Banner')
          .uploadBinary(
            filePath,
            _selectedImageBytes!,
            fileOptions: FileOptions(
              contentType: 'image/$fileExtension',
              upsert: true,
            ),
          );

      // Get public URL to save it in database
      final imageUrl = Supabase.instance.client.storage
          .from('Battle Master Banner')
          .getPublicUrl(filePath);

      // Insert new banner record into app_banners table
      await Supabase.instance.client.from('app_banners').insert({
        'image_url': imageUrl,
        'is_active': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Banner uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedImageBytes = null;
          _selectedImageName = null;
        });
        _fetchBanners();
      }
    } on StorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Toggle Active Status
  Future<void> _toggleBannerStatus(int id, bool currentStatus) async {
    try {
      await Supabase.instance.client
          .from('app_banners')
          .update({'is_active': !currentStatus})
          .eq('id', id);
      _fetchBanners();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update Banner Image
  Future<void> _updateBannerImage(int id, String oldImageUrl) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading new image...')));
      }

      final bytes = await image.readAsBytes();
      final fileExt = image.name.contains('.')
          ? image.name.split('.').last
          : 'jpg';
      final fileName =
          'banner_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'uploads/$fileName';

      // Upload new image
      await Supabase.instance.client.storage
          .from('Battle Master Banner')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true,
            ),
          );

      final newImageUrl = Supabase.instance.client.storage
          .from('Battle Master Banner')
          .getPublicUrl(filePath);

      // Update database
      await Supabase.instance.client
          .from('app_banners')
          .update({'image_url': newImageUrl})
          .eq('id', id);

      // Delete old image from storage
      _deleteImageFromStorage(oldImageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Banner updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _fetchBanners();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating banner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Delete Banner completely
  Future<void> _deleteBanner(int id, String imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete Banner?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this banner? It will be removed from storage too.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete from database
      await Supabase.instance.client.from('app_banners').delete().eq('id', id);

      // Delete from storage
      await _deleteImageFromStorage(imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Banner deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _fetchBanners();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting banner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper to extract path and delete from Supabase storage
  Future<void> _deleteImageFromStorage(String imageUrl) async {
    String filePath = '';
    if (imageUrl.contains('Battle Master Banner/')) {
      filePath = imageUrl.split('Battle Master Banner/').last;
    } else if (imageUrl.contains('Battle%20Master%20Banner/')) {
      filePath = imageUrl.split('Battle%20Master%20Banner/').last;
    }

    if (filePath.isNotEmpty) {
      filePath = Uri.decodeComponent(filePath.split('?').first);
      await Supabase.instance.client.storage
          .from('Battle Master Banner')
          .remove([filePath]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🖼️ Manage App Banners',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_selectedImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _selectedImageBytes!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade800,
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'No Image Selected',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickImage,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Select Image'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _uploadImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            foregroundColor: Colors.white,
                          ),
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(
                            _isUploading ? 'Uploading...' : 'Upload to App',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '📋 Uploaded Banners',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildBannersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBannersList() {
    if (_isLoadingBanners) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    if (_banners.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No banners uploaded yet.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _banners.length,
      itemBuilder: (context, index) {
        final banner = _banners[index];
        final isActive = banner['is_active'] == true;

        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  banner['image_url'],
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.broken_image,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Switch(
                          value: isActive,
                          activeThumbColor: Colors.green,
                          inactiveThumbColor: Colors.grey,
                          inactiveTrackColor: Colors.grey[800],
                          onChanged: (value) =>
                              _toggleBannerStatus(banner['id'], isActive),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: isActive ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                          ),
                          tooltip: 'Update Image',
                          onPressed: () => _updateBannerImage(
                            banner['id'],
                            banner['image_url'],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Banner',
                          onPressed: () =>
                              _deleteBanner(banner['id'], banner['image_url']),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
