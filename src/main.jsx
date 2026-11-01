import React from 'react';
import { createRoot } from 'react-dom/client';
import { Analytics } from '@vercel/analytics/react';
import App from './App.jsx';
import './style.css';

class AppErrorBoundary extends React.Component {
  state = { failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  componentDidCatch(error) { console.error('CampusVault render error:', error); }
  render() {
    if (this.state.failed) return <main style={{maxWidth:560,margin:'12vh auto',padding:24,fontFamily:'system-ui',color:'#25332d'}}>
      <h1>CampusVault hit an error</h1>
      <p>Your demo data is still saved in this browser. Reload the page to try again. If the problem repeats, clear site storage for the local demo address.</p>
      <button onClick={() => window.location.reload()} style={{padding:'10px 14px',background:'#287c67',color:'#fff',border:0,borderRadius:6,cursor:'pointer'}}>Reload CampusVault</button>
    </main>;
    return this.props.children;
  }
}

createRoot(document.getElementById('root')).render(<React.StrictMode><AppErrorBoundary><App /><Analytics /></AppErrorBoundary></React.StrictMode>);
