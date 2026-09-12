import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/diario_contact.dart';
import '../models/diario_category.dart';
import '../models/diario_template.dart';
import '../models/diario_entry.dart';

class DiarioSupabaseService {
  static final DiarioSupabaseService instance = DiarioSupabaseService._init();
  DiarioSupabaseService._init();

  SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isReady => client != null;

  // ===========================================================================
  // CONTACTS
  // ===========================================================================
  Future<List<DiarioContact>> getContacts() async {
    if (!isReady) return _getDefaultContacts();
    try {
      final List response = await client!
          .from('diario_contacts')
          .select()
          .order('name', ascending: true);

      if (response.isEmpty) {
        return _getDefaultContacts();
      }
      return response
          .map((row) => DiarioContact.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Info: Usando contactos locales/reserva ($e)');
      return _getDefaultContacts();
    }
  }

  Future<void> saveContact(DiarioContact contact) async {
    if (!isReady) return;
    try {
      final map = contact.toMap();
      final user = client?.auth.currentUser;
      if (user != null) {
        map['user_id'] = user.id;
      }
      await client!.from('diario_contacts').upsert(map, onConflict: 'id');
    } catch (e) {
      debugPrint('Error guardando contacto en Supabase: $e');
    }
  }

  Future<void> deleteContact(String id) async {
    if (!isReady) return;
    try {
      await client!.from('diario_contacts').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error eliminando contacto en Supabase: $e');
    }
  }

  // ===========================================================================
  // CATEGORIES
  // ===========================================================================
  Future<List<DiarioCategory>> getCategories() async {
    if (!isReady) return _getDefaultCategories();
    try {
      final List response = await client!
          .from('diario_categories')
          .select()
          .order('sort_order', ascending: true);

      if (response.isEmpty) {
        return _getDefaultCategories();
      }
      return response
          .map((row) => DiarioCategory.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Info: Usando categorías locales/reserva ($e)');
      return _getDefaultCategories();
    }
  }

  Future<void> saveCategory(DiarioCategory category) async {
    if (!isReady) return;
    try {
      final map = category.toMap();
      final user = client?.auth.currentUser;
      if (user != null) {
        map['user_id'] = user.id;
      }
      await client!.from('diario_categories').upsert(map, onConflict: 'id');
    } catch (e) {
      debugPrint('Error guardando categoría en Supabase: $e');
    }
  }

  Future<void> deleteCategory(String id) async {
    if (!isReady) return;
    try {
      await client!.from('diario_categories').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error eliminando categoría en Supabase: $e');
    }
  }

  // ===========================================================================
  // TEMPLATES (MODELOS)
  // ===========================================================================
  Future<List<DiarioTemplate>> getTemplates() async {
    if (!isReady) return _getDefaultTemplates();
    try {
      final List response = await client!
          .from('diario_templates')
          .select()
          .order('name', ascending: true);

      if (response.isEmpty) {
        return _getDefaultTemplates();
      }
      return response
          .map((row) => DiarioTemplate.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Info: Usando plantillas locales/reserva ($e)');
      return _getDefaultTemplates();
    }
  }

  Future<void> saveTemplate(DiarioTemplate template) async {
    if (!isReady) return;
    try {
      final map = template.toMap();
      final user = client?.auth.currentUser;
      if (user != null) {
        map['user_id'] = user.id;
      }
      await client!.from('diario_templates').upsert(map, onConflict: 'id');
    } catch (e) {
      debugPrint('Error guardando plantilla en Supabase: $e');
    }
  }

  Future<void> deleteTemplate(String id) async {
    if (!isReady) return;
    try {
      await client!.from('diario_templates').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error eliminando plantilla en Supabase: $e');
    }
  }

  // ===========================================================================
  // ENTRIES (REGISTROS)
  // ===========================================================================
  Future<List<DiarioEntry>> getEntries() async {
    if (!isReady) return _getDefaultEntries();
    try {
      final List response = await client!
          .from('diario_entries')
          .select()
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return _getDefaultEntries();
      }
      return response
          .map((row) => DiarioEntry.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Info: Usando entradas locales/reserva ($e)');
      return _getDefaultEntries();
    }
  }

  Future<void> saveEntry(DiarioEntry entry) async {
    if (!isReady) return;
    try {
      final map = entry.toMap();
      final user = client?.auth.currentUser;
      if (user != null) {
        map['user_id'] = user.id;
      }
      await client!.from('diario_entries').upsert(map, onConflict: 'id');
    } catch (e) {
      debugPrint('Error guardando entrada en Supabase: $e');
    }
  }

  Future<void> deleteEntry(String id) async {
    if (!isReady) return;
    try {
      await client!.from('diario_entries').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error eliminando entrada en Supabase: $e');
    }
  }

  // ===========================================================================
  // DEFAULT IN-MEMORY SEEDS (Garantizan funcionamiento inmediato fuera de caja)
  // ===========================================================================
  List<DiarioContact> _getDefaultContacts() {
    return [
      DiarioContact(
        id: 'contact_sobrina',
        name: 'Camila Ortiz',
        nickname: 'Sobrini',
        relationship: 'Sobrina',
        avatarColor: '#1F6F5F',
        birthdate: DateTime(2014, 5, 18),
        phone: '+58 414-5550192',
        notes: 'Le encantan las manualidades, el anime y los postres de chocolate.',
        isFavorite: true,
      ),
      DiarioContact(
        id: 'contact_novia',
        name: 'Valentina Gómez',
        nickname: 'Mi Amor',
        relationship: 'Novia',
        avatarColor: '#1F6F5F',
        birthdate: DateTime(1998, 10, 24),
        phone: '+58 424-7771234',
        notes: 'Flor favorita: Tulipanes amarillos. Café favorito: Vainilla latte.',
        isFavorite: true,
      ),
      DiarioContact(
        id: 'contact_amigo',
        name: 'Carlos Mendoza',
        nickname: 'Carlitos',
        relationship: 'Amigo',
        avatarColor: '#1F6F5F',
        birthdate: DateTime(1995, 3, 12),
        phone: '+58 412-8889900',
        notes: 'Ingeniero, amante de los autos deportivos y la cocina.',
        isFavorite: false,
      ),
    ];
  }

  List<DiarioCategory> _getDefaultCategories() {
    return [
      // Raíces
      DiarioCategory(id: 'cat_alimentos', name: 'Alimentos & Bebidas', icon: 'restaurant', colorHex: '#1F6F5F', sortOrder: 1),
      DiarioCategory(id: 'cat_regalos', name: 'Regalos & Deseos', icon: 'card_giftcard', colorHex: '#1F6F5F', sortOrder: 2),
      DiarioCategory(id: 'cat_vehiculos', name: 'Vehículos & Transporte', icon: 'directions_car', colorHex: '#1F6F5F', sortOrder: 3),
      DiarioCategory(id: 'cat_salud', name: 'Salud & Medidas', icon: 'favorite', colorHex: '#1F6F5F', sortOrder: 4),
      DiarioCategory(id: 'cat_finanzas', name: 'Finanzas & Cuentas', icon: 'account_balance', colorHex: '#1F6F5F', sortOrder: 5),
      DiarioCategory(id: 'cat_mascotas', name: 'Mascotas', icon: 'pets', colorHex: '#1F6F5F', sortOrder: 6),

      // Subcategorías
      DiarioCategory(id: 'cat_alimentos_favoritos', parentId: 'cat_alimentos', name: 'Me Gusta / Favoritos', icon: 'thumb_up', colorHex: '#1F6F5F', sortOrder: 1),
      DiarioCategory(id: 'cat_alimentos_disgustos', parentId: 'cat_alimentos', name: 'No Le Gusta / Detesta', icon: 'thumb_down', colorHex: '#1F6F5F', sortOrder: 2),
      DiarioCategory(id: 'cat_regalos_cumple', parentId: 'cat_regalos', name: 'Ideas de Cumpleaños', icon: 'cake', colorHex: '#1F6F5F', sortOrder: 1),
      DiarioCategory(id: 'cat_regalos_deseos', parentId: 'cat_regalos', name: 'Cosas que quiere comprar', icon: 'shopping_bag', colorHex: '#1F6F5F', sortOrder: 2),
      DiarioCategory(id: 'cat_salud_tallas', parentId: 'cat_salud', name: 'Tallas de Ropa & Calzado', icon: 'straighten', colorHex: '#1F6F5F', sortOrder: 1),
      DiarioCategory(id: 'cat_salud_alergias', parentId: 'cat_salud', name: 'Alergias & Restricciones', icon: 'medical_services', colorHex: '#1F6F5F', sortOrder: 2),
    ];
  }

  List<DiarioTemplate> _getDefaultTemplates() {
    return [
      DiarioTemplate(
        id: 'tpl_automovil',
        name: 'Automóvil / Vehículo',
        description: 'Datos de vehículos asociados a un contacto: placa, marca, modelo, año y color.',
        icon: 'directions_car',
        colorHex: '#1F6F5F',
        isSystem: true,
        fields: [
          TemplateField(key: 'marca', label: 'Marca', type: TemplateFieldType.text, required: true, placeholder: 'Ej: Toyota, Chevrolet, Ford'),
          TemplateField(key: 'modelo', label: 'Modelo', type: TemplateFieldType.text, required: true, placeholder: 'Ej: Corolla, Spark, Explorer'),
          TemplateField(key: 'anio', label: 'Año', type: TemplateFieldType.number, placeholder: 'Ej: 2022'),
          TemplateField(key: 'placa', label: 'Placa', type: TemplateFieldType.text, required: true, placeholder: 'Ej: ABC123D'),
          TemplateField(key: 'color', label: 'Color', type: TemplateFieldType.text, placeholder: 'Ej: Plata, Blanco, Azul'),
          TemplateField(key: 'notas', label: 'Notas / Seguro', type: TemplateFieldType.multiline, placeholder: 'Póliza, taller de confianza, etc.'),
        ],
      ),
      DiarioTemplate(
        id: 'tpl_ropa_tallas',
        name: 'Tallas de Ropa / Calzado',
        description: 'Tallas, medidas y preferencias de vestimenta para regalos y compras.',
        icon: 'straighten',
        colorHex: '#1F6F5F',
        isSystem: true,
        fields: [
          TemplateField(key: 'tipo', label: 'Tipo de Prenda / Accesorio', type: TemplateFieldType.select, required: true, options: [
            'Calzado', 'Camisa / Blusa', 'Pantalón', 'Vestido', 'Ropa Interior', 'Anillo / Joyería', 'Gorra / Sombrero'
          ]),
          TemplateField(key: 'talla', label: 'Talla / Medida exacta', type: TemplateFieldType.text, required: true, placeholder: 'Ej: 41, M, 32/30, US 9'),
          TemplateField(key: 'marcas', label: 'Marcas Favoritas', type: TemplateFieldType.text, placeholder: 'Ej: Zara, Nike, Levi\'s'),
          TemplateField(key: 'notas', label: 'Notas de Ajuste', type: TemplateFieldType.multiline, placeholder: 'Ej: Horma ancha, prefiere corte holgado'),
        ],
      ),
      DiarioTemplate(
        id: 'tpl_cuenta_bancaria',
        name: 'Cuenta Bancaria / Pago Móvil',
        description: 'Datos bancarios para transferencias inmediatas y pagos a contactos.',
        icon: 'credit_card',
        colorHex: '#1F6F5F',
        isSystem: true,
        fields: [
          TemplateField(key: 'banco', label: 'Banco', type: TemplateFieldType.text, required: true, placeholder: 'Ej: Banesco, Mercantil, BDV, Chase'),
          TemplateField(key: 'titular', label: 'Titular de la cuenta', type: TemplateFieldType.text, required: true, placeholder: 'Nombre y Apellido'),
          TemplateField(key: 'identificacion', label: 'Cédula / RIF / ID', type: TemplateFieldType.text, required: true, placeholder: 'Ej: V-12345678'),
          TemplateField(key: 'numero_cuenta', label: 'Número de Cuenta (20 dígitos)', type: TemplateFieldType.text, placeholder: '0134...'),
          TemplateField(key: 'pago_movil', label: 'Teléfono Pago Móvil', type: TemplateFieldType.text, placeholder: '0414-1234567'),
          TemplateField(key: 'zelle_correo', label: 'Correo Zelle / PayPal', type: TemplateFieldType.text, placeholder: 'ejemplo@correo.com'),
        ],
      ),
      DiarioTemplate(
        id: 'tpl_preferencia_comida',
        name: 'Preferencia Gastronómica',
        description: 'Platos, bebidas y alimentos favoritos, alergias o disgustos culinarios.',
        icon: 'restaurant',
        colorHex: '#1F6F5F',
        isSystem: true,
        fields: [
          TemplateField(key: 'alimento', label: 'Plato / Alimento', type: TemplateFieldType.text, required: true, placeholder: 'Ej: Pasta de hígado, Sushi, Café con leche'),
          TemplateField(key: 'gusto', label: 'Preferencia', type: TemplateFieldType.select, required: true, options: [
            'Le fascina / Favorito', 'Le gusta', 'No le gusta', 'Detesta / No come', 'Alergia / Intolerancia'
          ]),
          TemplateField(key: 'lugar', label: 'Restaurante / Lugar preferido', type: TemplateFieldType.text, placeholder: 'Dónde le gusta comerlo'),
          TemplateField(key: 'detalles', label: 'Cómo le gusta preparado', type: TemplateFieldType.multiline, placeholder: 'Ej: Sin cebolla, término medio, leche deslactosada'),
        ],
      ),
      DiarioTemplate(
        id: 'tpl_idea_regalo',
        name: 'Idea de Regalo / Deseo',
        description: 'Lista de deseos, cosas que le gustaría tener u obsequios planificados.',
        icon: 'card_giftcard',
        colorHex: '#1F6F5F',
        isSystem: true,
        fields: [
          TemplateField(key: 'articulo', label: 'Artículo / Objeto de Regalo', type: TemplateFieldType.text, required: true, placeholder: 'Ej: Perfume Acqua di Gio, Libro Sci-Fi'),
          TemplateField(key: 'ocasion', label: 'Ocasión Ideal', type: TemplateFieldType.select, options: [
            'Cumpleaños', 'Navidad', 'Aniversario', 'Graduación', 'Sorpresa espontánea'
          ]),
          TemplateField(key: 'precio', label: 'Precio Aproximado (\$)', type: TemplateFieldType.number, placeholder: 'Ej: 45.00'),
          TemplateField(key: 'tienda_link', label: 'Tienda o Enlace web', type: TemplateFieldType.text, placeholder: 'Amazon, MercadoLibre, tienda física'),
          TemplateField(key: 'estado', label: 'Estado del Regalo', type: TemplateFieldType.select, required: true, options: [
            'Idea pendiente', 'Planeado comprar', 'Comprado / Entregado'
          ]),
        ],
      ),
      DiarioTemplate(
        id: 'tpl_mascota',
        name: 'Mascota de Contacto',
        description: 'Datos de las mascotas de personas cercanas: nombre, raza, veterinario.',
        icon: 'pets',
        colorHex: '#1F6F5F',
        isSystem: true,
        fields: [
          TemplateField(key: 'nombre', label: 'Nombre de la Mascota', type: TemplateFieldType.text, required: true, placeholder: 'Ej: Firulais, Luna'),
          TemplateField(key: 'especie_raza', label: 'Especie / Raza', type: TemplateFieldType.text, required: true, placeholder: 'Ej: Perro Golden Retriever, Gato Siamés'),
          TemplateField(key: 'edad_cumple', label: 'Edad o Fecha de Nacimiento', type: TemplateFieldType.text, placeholder: 'Ej: 3 años / 15 de Mayo'),
          TemplateField(key: 'notas', label: 'Notas / Vacunas', type: TemplateFieldType.multiline, placeholder: 'Alergias, alimentos prohibidos, veterinario'),
        ],
      ),
    ];
  }

  List<DiarioEntry> _getDefaultEntries() {
    return [
      // Entrada de la sobrina con Pasta de hígado (Ejemplo exacto del usuario)
      DiarioEntry(
        id: 'entry_sobrina_pasta',
        contactId: 'contact_sobrina',
        categoryId: 'cat_alimentos_favoritos',
        templateId: 'tpl_preferencia_comida',
        entryType: 'template_instance',
        title: 'Pasta de hígado',
        contentText: 'Su comida favorita absoluta en los almuerzos.',
        contentData: {
          'alimento': 'Pasta de hígado',
          'gusto': 'Le fascina / Favorito',
          'lugar': 'Hecha en casa de la abuela',
          'detalles': 'Le gusta con bastante queso rallado por encima',
        },
        isPinned: true,
      ),
      // Entrada de la sobrina con disgusto
      DiarioEntry(
        id: 'entry_sobrina_brocoli',
        contactId: 'contact_sobrina',
        categoryId: 'cat_alimentos_disgustos',
        templateId: 'tpl_preferencia_comida',
        entryType: 'template_instance',
        title: 'Brócoli y Coliflor',
        contentText: 'No le gusta para nada el olor ni la textura.',
        contentData: {
          'alimento': 'Brócoli y Coliflor',
          'gusto': 'Detesta / No come',
          'lugar': '',
          'detalles': 'Evitar colocarlo en la comida',
        },
        isPinned: false,
      ),
      // Entrada de la novia con ideas de regalo (Ejemplo exacto del usuario)
      DiarioEntry(
        id: 'entry_novia_regalo_1',
        contactId: 'contact_novia',
        categoryId: 'cat_regalos_deseos',
        templateId: 'tpl_idea_regalo',
        entryType: 'template_instance',
        title: 'Perfume Floral Dior Blooming Bouquet',
        contentText: 'Lo vio en una tienda y le fascinó el aroma.',
        contentData: {
          'articulo': 'Dior Miss Dior Blooming Bouquet (100ml)',
          'ocasion': 'Cumpleaños',
          'precio': 135.00,
          'tienda_link': 'Sephora / Tienda La Riviera',
          'estado': 'Planeado comprar',
        },
        isPinned: true,
      ),
      // Entrada de la novia con talla de calzado
      DiarioEntry(
        id: 'entry_novia_talla_calzado',
        contactId: 'contact_novia',
        categoryId: 'cat_salud_tallas',
        templateId: 'tpl_ropa_tallas',
        entryType: 'template_instance',
        title: 'Calzado / Zapatos',
        contentText: 'Talla de calzado para tacones y zapatillas casuales.',
        contentData: {
          'tipo': 'Calzado',
          'talla': '37 EUR / 6.5 US',
          'marcas': 'Zara, Adidas Samba',
          'notas': 'Prefiere horma cómoda, sin tacones demasiado altos.',
        },
        isPinned: false,
      ),
      // Entrada de auto de Carlos Mendoza (Ejemplo exacto del usuario)
      DiarioEntry(
        id: 'entry_carlos_auto',
        contactId: 'contact_amigo',
        categoryId: 'cat_vehiculos',
        templateId: 'tpl_automovil',
        entryType: 'template_instance',
        title: 'Toyota Corolla 2022',
        contentText: 'Vehículo principal de uso diario.',
        contentData: {
          'marca': 'Toyota',
          'modelo': 'Corolla XLE',
          'anio': 2022,
          'placa': 'AB-492-CD',
          'color': 'Gris Plata Metalizado',
          'notas': 'Mantenimiento en concesionario oficial cada 5.000 km.',
        },
        isPinned: true,
      ),
    ];
  }
}
