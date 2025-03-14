import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/inventory_item.dart';
import '../services/pocketbase_service.dart';
import '../services/image_service.dart';
import 'package:flutter/foundation.dart';

class ItemDetailScreen extends StatefulWidget {
  final InventoryItem item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  File? _imageFile;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _categoryController = TextEditingController(text: widget.item.category);
    _quantityController = TextEditingController(text: widget.item.quantity.toString());
    _priceController = TextEditingController(text: widget.item.price.toString());
    _descriptionController = TextEditingController(text: widget.item.description);
    _locationController = TextEditingController(text: widget.item.location);
  }

  Future<void> _pickImage() async {
    final File? image = await ImageService.pickAndCompressImage();
    
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _saveChanges() async {
    try {
      await context.read<PocketbaseService>().updateItem(
        widget.item.id,
        name: _nameController.text,
        category: _categoryController.text,
        quantity: int.parse(_quantityController.text),
        price: double.parse(_priceController.text),
        description: _descriptionController.text,
        location: _locationController.text,
        image: _imageFile,
      );
      
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Item Details'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveChanges();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Item'),
                    content: const Text('Are you sure you want to delete this item?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await context.read<PocketbaseService>().deleteItem(widget.item.id);
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.item.imageUrl != null || _imageFile != null)
              Center(
                child: GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _imageFile != null
                        ? kIsWeb 
                            ? const Center(child: Text("New image selected"))
                            : Image.file(_imageFile!, fit: BoxFit.cover)
                        : widget.item.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.item.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              )
                            : const Icon(Icons.image_not_supported, size: 50),
                  ),
                ),
              )
            else if (_isEditing)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Add Image'),
                ),
              ),
            const SizedBox(height: 16),
            _buildTextField(_nameController, 'Name', enabled: _isEditing),
            _buildTextField(_categoryController, 'Category', enabled: _isEditing),
            _buildTextField(_quantityController, 'Quantity',
                enabled: _isEditing, keyboardType: TextInputType.number),
            _buildTextField(_priceController, 'Price',
                enabled: _isEditing, keyboardType: TextInputType.number),
            _buildTextField(_descriptionController, 'Description',
                enabled: _isEditing, maxLines: 3),
            _buildTextField(_locationController, 'Location', enabled: _isEditing),
            const SizedBox(height: 16),
            if (!_isEditing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Created: ${widget.item.createdAt.toLocal()}'),
                  Text('Last Updated: ${widget.item.updatedAt.toLocal()}'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
} 