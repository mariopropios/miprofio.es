import 'legal_constants.dart';

class LegalSection {
  const LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSection> sections;
}

/// Contenidos legales (español). Fácil de editar.
abstract final class LegalDocuments {
  LegalDocuments._();

  static LegalDocument get privacy => LegalDocument(
        title: 'Política de privacidad',
        intro:
            'En ${LegalConstants.brandName} nos tomamos en serio tu privacidad. '
            'Esta política explica qué datos tratamos, para qué y cuáles son tus derechos. '
            'Última actualización: ${LegalConstants.lastUpdated}.\n\n'
            '${LegalConstants.disclaimer}',
        sections: [
          LegalSection(
            title: '1. Responsable',
            body: 'Responsable del tratamiento:\n'
                '• ${LegalConstants.controllerName}\n'
                '• NIF/CIF: ${LegalConstants.taxId}\n'
                '• Domicilio: ${LegalConstants.address}\n'
                '• Email: ${LegalConstants.contactEmail}\n'
                '• Web: ${LegalConstants.siteUrl}',
          ),
          const LegalSection(
            title: '2. Datos que tratamos',
            body: 'Según cómo uses la plataforma, podemos tratar:\n'
                '• Datos de cuenta: email, nombre, contraseña (hash gestionado por el proveedor de auth), rol (cliente/profesional).\n'
                '• Perfil profesional: oficios, ciudad, descripción, fotos, teléfono/email de contacto, radio de desplazamiento, geolocalización aproximada si la facilitas.\n'
                '• Contenido generado: mensajes, reseñas, valoraciones, fotos de trabajos.\n'
                '• Datos técnicos: dirección IP, tipo de dispositivo/navegador, registros de seguridad y preferencias locales (p. ej. instalación PWA).\n'
                '• Notificaciones: token de push (Firebase Cloud Messaging) si activas avisos.\n'
                '• Comunicaciones: emails transaccionales (nuevos mensajes, reseñas) si están habilitados.',
          ),
          const LegalSection(
            title: '3. Finalidades y bases legales',
            body: '• Prestación del servicio (cuenta, fichas, chat, reseñas): ejecución del contrato / medidas precontractuales.\n'
                '• Seguridad y prevención de abuso: interés legítimo y, en su caso, obligación legal.\n'
                '• Geolocalización para búsqueda por proximidad: consentimiento o interés legítimo según el contexto; puedes no usarla.\n'
                '• Notificaciones push y emails de avisos: consentimiento / configuración de preferencias.\n'
                '• Mejora del servicio y métricas técnicas estrictamente necesarias: interés legítimo.\n'
                'No usamos Google Analytics ni cookies de publicidad de terceros en este momento.',
          ),
          const LegalSection(
            title: '4. Encargados y proveedores',
            body: 'Pueden intervenir, entre otros:\n'
                '• Supabase (autenticación, base de datos y almacenamiento).\n'
                '• Firebase / Google (notificaciones push FCM).\n'
                '• Resend (envío de emails transaccionales).\n'
                '• Cloudflare (alojamiento/CDN de la web).\n'
                'Estos proveedores actúan según sus propias condiciones y, cuando aplica, como encargados del tratamiento.',
          ),
          const LegalSection(
            title: '5. Conservación',
            body: 'Conservamos los datos mientras mantengas la cuenta y el tiempo necesario '
                'para la prestación del servicio, obligaciones legales o resolución de incidencias. '
                'Si eliminas tu cuenta, dejamos de tratar activamente tus datos de perfil/ficha '
                '(la ficha profesional deja de ser pública) y borramos o anonimizamos lo que corresponda, '
                'salvo bloqueos legales o copias de seguridad temporales.',
          ),
          const LegalSection(
            title: '6. Destinatarios y transferencias',
            body: 'No vendemos tus datos. Pueden acceder proveedores técnicos necesarios para operar '
                'el servicio. Algunos proveedores pueden estar fuera del EEE; en ese caso se usan '
                'mecanismos adecuados (p. ej. cláusulas contractuales tipo) cuando procede.',
          ),
          const LegalSection(
            title: '7. Tus derechos',
            body: 'Puedes ejercer acceso, rectificación, supresión, oposición, limitación y portabilidad, '
                'así como retirar consentimientos, escribiendo a ${LegalConstants.contactEmail}. '
                'También puedes reclamar ante la Agencia Española de Protección de Datos (AEPD). '
                'Desde la app puedes editar tu perfil y solicitar la eliminación de cuenta.',
          ),
          const LegalSection(
            title: '8. Menores',
            body: 'El servicio está dirigido a mayores de 18 años. Si detectamos una cuenta de un menor, '
                'podremos eliminarla.',
          ),
          const LegalSection(
            title: '9. Cambios',
            body: 'Podemos actualizar esta política. Publicaremos la versión vigente en esta página '
                'con la fecha de actualización.',
          ),
        ],
      );

  static LegalDocument get cookies => LegalDocument(
        title: 'Política de cookies',
        intro:
            'Esta política explica qué cookies y tecnologías similares usa ${LegalConstants.brandName}. '
            'Última actualización: ${LegalConstants.lastUpdated}.\n\n'
            '${LegalConstants.disclaimer}',
        sections: [
          const LegalSection(
            title: '1. ¿Qué son?',
            body: 'Las cookies y tecnologías similares (localStorage, sessionStorage, identificadores '
                'del navegador) permiten recordar preferencias, mantener la sesión o entender el uso '
                'del sitio. En una PWA también se usan para instalación y notificaciones.',
          ),
          const LegalSection(
            title: '2. Cookies / tecnologías necesarias',
            body: 'Estas son imprescindibles para el funcionamiento y no se pueden rechazar sin romper el servicio:\n'
                '• Sesión y autenticación (Supabase Auth).\n'
                '• Seguridad y prevención de fraude.\n'
                '• Preferencias esenciales de la PWA (p. ej. recordatorio de «añadir al inicio»).\n'
                '• Elección de consentimiento de cookies (para no preguntarte en cada visita).',
          ),
          const LegalSection(
            title: '3. Opcionales (analytics / marketing)',
            body: 'Hoy ${LegalConstants.brandName} no carga Google Analytics ni cookies publicitarias de terceros. '
                'Si en el futuro activamos métricas opcionales, solo se usarán si las aceptas en el banner '
                'de preferencias. Puedes rechazarlas sin perder el uso esencial de la web.',
          ),
          const LegalSection(
            title: '4. Otras tecnologías',
            body: '• Firebase Cloud Messaging: solo si activas notificaciones push (token en tu perfil).\n'
                '• Geolocalización del navegador: solo cuando la solicitas o usas funciones que la necesitan.\n'
                '• Almacenamiento local: preferencias de UI/PWA en tu dispositivo.',
          ),
          const LegalSection(
            title: '5. Cómo gestionarlas',
            body: 'Puedes aceptar, rechazar opcionales o abrir «Configurar» en el banner. '
                'También puedes borrar datos del sitio desde la configuración de tu navegador. '
                'Más información en la Política de privacidad.',
          ),
        ],
      );

  static LegalDocument get terms => LegalDocument(
        title: 'Términos y condiciones',
        intro:
            'Estos términos regulan el uso de ${LegalConstants.brandName}. '
            'Al crear una cuenta o usar la plataforma aceptas estas condiciones. '
            'Última actualización: ${LegalConstants.lastUpdated}.\n\n'
            '${LegalConstants.disclaimer}',
        sections: [
          LegalSection(
            title: '1. El servicio',
            body: '${LegalConstants.brandName} es un directorio y comunidad para poner en contacto '
                'a clientes con profesionales del hogar, con reseñas y mensajería. '
                'No somos parte del contrato de obra o servicio entre usuarios, salvo que se indique lo contrario.',
          ),
          const LegalSection(
            title: '2. Cuentas',
            body: 'Debes facilitar datos veraces y mantener la confidencialidad de tu acceso. '
                'Eres responsable de la actividad realizada con tu cuenta. '
                'Podemos suspender cuentas por fraude, abuso, spam o incumplimiento.',
          ),
          const LegalSection(
            title: '3. Profesionales y clientes',
            body: '• Los profesionales son responsables de la exactitud de su ficha, precios orientativos, '
                'disponibilidad y cumplimiento de normativa de su oficio.\n'
                '• Las reseñas deben basarse en experiencia real; no se permiten reseñas falsas ni manipulación.\n'
                '• El chat debe usarse de forma respetuosa y lícita.',
          ),
          const LegalSection(
            title: '4. Contenidos',
            body: 'Conservas los derechos sobre tu contenido, pero nos concedes licencia para mostrarlo '
                'en la plataforma (ficha, galería, reseñas) mientras esté publicado. '
                'No subas material ilegal, ofensivo o que vulnere derechos de terceros.',
          ),
          const LegalSection(
            title: '5. Disponibilidad',
            body: 'Nos esforzamos por mantener el servicio disponible, pero no garantizamos ausencia de '
                'interrupciones, errores o pérdida de datos. El servicio se ofrece «tal cual».',
          ),
          LegalSection(
            title: '6. Limitación de responsabilidad',
            body: 'En la medida permitida por la ley, ${LegalConstants.brandName} no responde de '
                'disputas, daños o incumplimientos entre clientes y profesionales, ni de trabajos '
                'contratados fuera de la plataforma.',
          ),
          LegalSection(
            title: '7. Contacto',
            body: 'Para dudas sobre estos términos: ${LegalConstants.contactEmail}.',
          ),
        ],
      );

  static LegalDocument get legalNotice => LegalDocument(
        title: 'Aviso legal',
        intro:
            'Información del titular del sitio web ${LegalConstants.brandName}. '
            'Última actualización: ${LegalConstants.lastUpdated}.',
        sections: [
          LegalSection(
            title: '1. Datos identificativos',
            body: '• Titular: ${LegalConstants.controllerName}\n'
                '• NIF/CIF: ${LegalConstants.taxId}\n'
                '• Domicilio: ${LegalConstants.address}\n'
                '• Email: ${LegalConstants.contactEmail}\n'
                '• Web: ${LegalConstants.siteUrl}',
          ),
          const LegalSection(
            title: '2. Objeto',
            body: 'El sitio facilita información y herramientas para localizar y contactar profesionales '
                'del hogar, así como dejar reseñas y mensajes entre usuarios.',
          ),
          const LegalSection(
            title: '3. Propiedad intelectual',
            body: 'La marca, diseño y software de la plataforma están protegidos. '
                'No está permitido copiarlos o explotarlos sin autorización.',
          ),
          LegalSection(
            title: '4. Contacto',
            body: 'Para notificaciones legales: ${LegalConstants.contactEmail}.',
          ),
        ],
      );
}
