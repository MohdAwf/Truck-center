import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/inventory_item.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class PocketbaseService extends ChangeNotifier {
  final PocketBase pb = PocketBase('http://localhost:8090/');

  Future<List<InventoryItem>> getItems({String? search, String? category}) async {
    final List<String> filter = [];
    
    if (search != null && search.isNotEmpty) {
      filter.add('name ~ "$search" || description ~ "$search"');
    }
    
    if (category != null && category.isNotEmpty) {
      filter.add('category = "$category"');
    }

    final records = await pb.collection('items').getFullList(
      sort: '-created',
      filter: filter.isEmpty ? null : filter.join(' && '),
    );
    
    return records.map((record) => InventoryItem.fromRecord(record)).toList();
  }

  Future<List<String>> getCategories() async {
    final records = await pb.collection('items').getFullList();
    return records
        .map((record) => record.data['category'].toString())
        .toSet()
        .toList();
  }

  Future<InventoryItem> addItem({
    required String name,
    required String category,
    required int quantity,
    required double price,
    String? description,
    String? location,
    File? image,
  }) async {
    String? imageUrl;
    
    if (image != null) {
      imageUrl = await _uploadCompressedImage(image);
    }

    final body = {
      "name": name,
      "category": category,
      "quantity": quantity,
      "price": price,
      "description": description ?? "",
      "location": location ?? "",
    };

    if (imageUrl != null && imageUrl.isNotEmpty) {
      body["image"] = imageUrl;
    }

    final record = await pb.collection('items').create(body: body);
    notifyListeners();
    return InventoryItem.fromRecord(record);
  }

  Future<InventoryItem> updateItem(
    String id, {
    String? name,
    String? category,
    int? quantity,
    double? price,
    String? description,
    String? location,
    File? image,
  }) async {
    try {
      final body = <String, dynamic>{};
      
      // Add all the text fields
      if (name != null) body["name"] = name;
      if (category != null) body["category"] = category;
      if (quantity != null) body["quantity"] = quantity;
      if (price != null) body["price"] = price;
      if (description != null) body["description"] = description;
      if (location != null) body["location"] = location;
      
      // If there's a new image, upload it first
      if (image != null) {
        final imageUrl = await _uploadCompressedImage(image);
        if (imageUrl.isNotEmpty) {
          body["image"] = imageUrl;
        }
      }
      
      // Update the record
      final record = await pb.collection('items').update(id, body: body);
      notifyListeners();
      return InventoryItem.fromRecord(record);
    } catch (e) {
      debugPrint('Error updating item: $e');
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    await pb.collection('items').delete(id);
    notifyListeners();
  }

  Future<String> _uploadCompressedImage(File imageFile) async {
    try {
      // For web platform
      if (kIsWeb) {
        // Get the bytes from the XFile
        final bytes = await XFile(imageFile.path).readAsBytes();
        
        // Create a form data request
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${pb.baseUrl}/api/collections/items/records'),
        );
        
        // Add required fields
        request.fields['name'] = "Temp Item ${DateTime.now().millisecondsSinceEpoch}";
        request.fields['category'] = "Temp";
        request.fields['quantity'] = "1";
        request.fields['price'] = "1.0";
        request.fields['description'] = "Temporary item";
        request.fields['location'] = "Temp";
        
        // Add the file with a simple filename
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: 'image.jpg',
          ),
        );
        
        // Send the request
        final response = await request.send();
        final responseBody = await http.Response.fromStream(response);
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          final jsonData = jsonDecode(responseBody.body);
          final imageUrl = jsonData['image'];
          
          // Delete the temporary record
          await pb.collection('items').delete(jsonData['id']);
          
          return imageUrl ?? '';
        } else {
          debugPrint('Error response: ${responseBody.body}');
          return '';
        }
      } 
      // For mobile platforms
      else {
        // Compress the image
        final tempDir = await getTemporaryDirectory();
        final targetPath = '${tempDir.path}/compressed.jpg';
        
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          imageFile.path,
          targetPath,
          quality: 70,
          minWidth: 800,
          minHeight: 800,
        );
        
        if (compressedFile == null) {
          throw Exception('Failed to compress image');
        }
        
        // Create a record with the required fields
        final formData = {
          'name': "Temp Item ${DateTime.now().millisecondsSinceEpoch}",
          'category': "Temp",
          'quantity': 1,
          'price': 1.0,
          'description': "Temporary item",
          'location': "Temp",
        };
        
        // Create the record and upload the file
        final record = await pb.collection('items').create(
          body: formData,
          files: [
            await http.MultipartFile.fromPath(
              'image',
              compressedFile.path,
            ),
          ],
        );
        
        // Get the image URL
        final imageUrl = record.data['image'];
        
        // Delete the temporary record
        await pb.collection('items').delete(record.id);
        
        return imageUrl ?? '';
      }
    } catch (e) {
      debugPrint('Error in _uploadCompressedImage: $e');
      return '';
    }
  }

  // Helper method to convert image bytes to base64
  Future<String> _imageToBase64(Uint8List bytes) async {
    final base64Image = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64Image';
  }

  Future<void> adjustQuantity(String id, int adjustment) async {
    final record = await pb.collection('items').getOne(id);
    final currentQuantity = record.data['quantity'] as int;
    final newQuantity = currentQuantity + adjustment;
    
    if (newQuantity < 0) {
      throw Exception('Quantity cannot be negative');
    }
    
    await updateItem(id, quantity: newQuantity);
  }

  String getFileUrl(String collectionId, String recordId, String filename) {
    if (filename.isEmpty) return '';
    return '${pb.baseUrl}/api/files/$collectionId/$recordId/$filename';
  }
} 