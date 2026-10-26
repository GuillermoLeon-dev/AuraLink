/**
 * Índice de la documentación del proyecto. Los PDF se compilan desde `docs/*.typ` en el
 * workflow de Pages y se publican en `<base>/docs/`; se abren con el visor del navegador.
 */
const DOCS: { code: string; file: string; title: string; summary: string }[] = [
  { code: 'AURA-DOC-09', file: '09-guia-de-uso.pdf', title: 'Guía de uso (tutorial)', summary: 'Paso a paso: planificar un viaje, leer los resultados y usar la consola técnica.' },
  { code: 'AURA-DOC-00', file: '00-estudio-mercado.pdf', title: 'Estudio de mercado y estado del arte', summary: 'Competidores, algoritmos de rutas, predicción y hueco de mercado.' },
  { code: 'AURA-DOC-01', file: '01-propuesta.pdf', title: 'Propuesta de valor y producto', summary: 'Usuarios, propuesta de valor, alcance del MVP e historias de usuario.' },
  { code: 'AURA-DOC-02', file: '02-arquitectura.pdf', title: 'Arquitectura, tecnologías y despliegue', summary: 'Decisiones de arquitectura, diagramas C4, motor McRAPTOR y despliegue.' },
  { code: 'AURA-DOC-03', file: '03-ml-crisp-ml.pdf', title: 'Aprendizaje automático y series temporales', summary: 'CRISP-ML(Q), modelos, resultados del backtesting y MLOps.' },
  { code: 'AURA-DOC-04', file: '04-innovacion-fusion.pdf', title: 'Innovación, data fusion y umbrales', summary: 'Fusión de fuentes, reglas de confianza y decisión humana.' },
  { code: 'AURA-DOC-05', file: '05-seguridad.pdf', title: 'Seguridad', summary: 'Modelo de amenazas STRIDE, controles, OWASP y pruebas.' },
  { code: 'AURA-DOC-06', file: '06-proteccion-datos.pdf', title: 'Protección de datos', summary: 'RGPD y LOPDGDD: datos tratados, bases jurídicas, RAT, riesgos y EIPD.' },
  { code: 'AURA-DOC-07', file: '07-viabilidad-economica.pdf', title: 'Viabilidad económica', summary: 'Costes, escalado, modelo de negocio y punto de equilibrio.' },
  { code: 'AURA-DOC-08', file: '08-informe-tiempos.pdf', title: 'Informe de tiempos del experimento', summary: 'Tiempo dedicado a cada etapa del desarrollo.' },
];

export function DocsPanel() {
  const base = `${import.meta.env.BASE_URL}docs/`;
  return (
    <div className="pad">
      <h3>Documentación</h3>
      <p className="hint">Cada documento se abre en una pestaña nueva con el visor de PDF del navegador.</p>
      <ul className="docs">
        {DOCS.map((d) => (
          <li key={d.file}>
            <a href={base + d.file} target="_blank" rel="noreferrer">
              <span className="doc-code">{d.code}</span>
              <strong>{d.title}</strong>
              <span className="muted small">{d.summary}</span>
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
