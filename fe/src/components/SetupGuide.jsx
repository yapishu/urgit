import Markdown from './Markdown'
import readme from '../../../docs/ci-setup-guide.md?raw'

// The operator's setup guide (BRIEF-CI-P3 D7/D8): docs/ci-setup-guide.md as
// built into the app, so "read the README" is one click from the CI tab
// and the Runners section and never a file the operator has to find.

export default function SetupGuide({ onClose }) {
  return <div className="modal-backdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
    <section className="modal-card ci-guide" role="dialog" aria-modal="true" aria-label="Runner setup guide">
      <header><div><span className="eyebrow">CI</span><h1>Runner setup guide</h1></div><button type="button" className="icon-button" onClick={onClose} aria-label="Close">×</button></header>
      <div className="modal-body markdown-body"><Markdown>{readme}</Markdown></div>
    </section>
  </div>
}
