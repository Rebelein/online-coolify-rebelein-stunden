import React, { ReactNode } from 'react';

interface GlassLayoutProps {
  children: ReactNode;
}

const GlassLayout: React.FC<GlassLayoutProps> = ({ children }) => {
  return (
    <div className="min-h-screen w-full relative bg-slate-950 text-slate-100 overflow-hidden selection:bg-teal-500/30 font-sans flex flex-col">
      <style>{`
        /* Dynamic Mesh Gradient Animation */
        @keyframes float {
          0% { transform: translate(0px, 0px) scale(1); }
          33% { transform: translate(30px, -50px) scale(1.1); }
          66% { transform: translate(-20px, 20px) scale(0.9); }
          100% { transform: translate(0px, 0px) scale(1); }
        }
        
        .mesh-blob {
          animation: float 20s ease-in-out infinite;
          opacity: 0.6;
        }

        .mesh-blob-delay-1 { animation-delay: -5s; }
        .mesh-blob-delay-2 { animation-delay: -12s; }

        /* Custom Scrollbar for the main content area */
        .glass-scrollbar::-webkit-scrollbar {
          width: 5px;
        }
        .glass-scrollbar::-webkit-scrollbar-track {
          background: rgba(255, 255, 255, 0.02);
        }
        .glass-scrollbar::-webkit-scrollbar-thumb {
          background: rgba(255, 255, 255, 0.1);
          border-radius: 10px;
        }
        .glass-scrollbar::-webkit-scrollbar-thumb:hover {
          background: rgba(255, 255, 255, 0.2);
        }
      `}</style>

      {/* Modern Mesh Gradient Background */}
      <div className="fixed inset-0 z-0 overflow-hidden pointer-events-none">
          {/* Deep Base Gradient */}
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-slate-900 via-slate-950 to-black" />
          
          {/* Vibrant Orbs */}
          {/* Top Right - Cyan/Teal */}
          <div className="mesh-blob absolute -top-[10%] -right-[10%] w-[50vw] h-[50vw] bg-teal-500/20 rounded-full blur-[100px] mix-blend-screen" />
          
          {/* Bottom Left - Emerald/Green */}
          <div className="mesh-blob mesh-blob-delay-1 absolute -bottom-[10%] -left-[10%] w-[60vw] h-[60vw] bg-emerald-600/20 rounded-full blur-[120px] mix-blend-screen" />
          
          {/* Center/Top - Blue/Purple Accent for depth */}
          <div className="mesh-blob mesh-blob-delay-2 absolute top-[20%] left-[20%] w-[40vw] h-[40vw] bg-blue-600/10 rounded-full blur-[100px] mix-blend-screen" />
      </div>

      {/* Main Content Container */}
      <SidebarAwareContainer>
        <div className="relative z-10 w-full h-full flex flex-col pointer-events-auto">
          {/* Max width container for large screens to prevent stretching */}
          <div className="w-full h-full mx-auto md:max-w-7xl px-0 md:px-4 lg:px-8 flex-1 flex flex-col">
             {children}
          </div>
        </div>
      </SidebarAwareContainer>
    </div>
  );
};

// Internal component to handle sidebar state to avoid re-rendering the whole layout unecessarily
const SidebarAwareContainer: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [isExpanded, setIsExpanded] = React.useState(() => {
    return typeof window !== 'undefined' ? localStorage.getItem('sidebarExpanded') === 'true' : false;
  });

  React.useEffect(() => {
    const handleToggle = () => {
      setIsExpanded(localStorage.getItem('sidebarExpanded') === 'true');
    };
    window.addEventListener('sidebar-toggle', handleToggle);
    return () => window.removeEventListener('sidebar-toggle', handleToggle);
  }, []);

  return (
    <div className={`relative z-10 w-full h-full min-h-screen flex flex-col transition-[padding] duration-300 ease-in-out ${isExpanded ? 'md:pl-64' : 'md:pl-24'}`}>
      {children}
    </div>
  );
};

export default GlassLayout;