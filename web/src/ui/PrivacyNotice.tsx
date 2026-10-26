/**
 * Información por capas (art. 11 LOPDGDD; arts. 12–14 RGPD). Primera capa breve y visible;
 * segunda capa completa. Detalle y base jurídica en AURA-DOC-06.
 */
export function PrivacyBanner({ onMore }: { onMore: () => void }) {
  return (
    <aside className="privacy-banner" aria-label="Información básica sobre protección de datos">
      <strong>Tu viaje no sale de tu dispositivo.</strong> Aura Link calcula las rutas en tu navegador: no
      registramos origen, destino ni ubicación, no usamos cookies ni analítica.{' '}
      <button className="link" onClick={onMore}>Información de protección de datos</button>
    </aside>
  );
}

export function PrivacyDetails() {
  return (
    <div className="pad prose">
      <h3>Protección de datos (segunda capa)</h3>
      <dl>
        <dt>Responsable</dt>
        <dd>Entidad que despliegue el piloto (p. ej. operador o ayuntamiento). Contacto del DPD: indicado en el despliegue.</dd>
        <dt>Qué datos tratamos de ti como usuario</dt>
        <dd>
          Ninguno en nuestros servidores. El origen, el destino y, si lo autorizas, tu ubicación se procesan
          exclusivamente en la memoria de tu navegador y se descartan al cerrar la página. No hay cuentas,
          cookies, almacenamiento local de trayectos ni analítica.
        </dd>
        <dt>Terceros técnicos</dt>
        <dd>
          Este sitio se aloja en GitHub Pages y el mapa usa teselas de OpenFreeMap: como en cualquier web,
          reciben la dirección IP y, en el caso del mapa, la zona visible. No reciben tu origen ni tu destino.
          Las tipografías se sirven desde este mismo sitio.
        </dd>
        <dt>Datos que usa el sistema</dt>
        <dd>Datos abiertos agregados (horarios, estado de estaciones, meteorología, calidad del aire, tráfico) sin datos personales.</dd>
        <dt>Personal técnico</dt>
        <dd>
          Las decisiones sobre alertas se registran en GitHub con el usuario del técnico (base jurídica: art. 6.1.b/c RGPD
          en el marco de la relación laboral; información conforme al art. 87–91 LOPDGDD).
        </dd>
        <dt>Derechos</dt>
        <dd>Acceso, rectificación, supresión, oposición, limitación y portabilidad ante el responsable; reclamación ante la AEPD (aepd.es).</dd>
      </dl>
    </div>
  );
}
