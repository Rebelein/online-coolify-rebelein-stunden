import React, { ReactNode } from 'react';

interface GlassCardProps {
  children: ReactNode;
  className?: string;
  onClick?: () => void;
  hoverEffect?: boolean;
}

export const GlassCard: React.FC<GlassCardProps> = ({ children, className = "", onClick, hoverEffect = false }) => {
  return (
    <div
      onClick={onClick}
      className={`
        relative overflow-hidden
        bg-white/[0.08] backdrop-blur-2xl
        border border-white/[0.15]
        shadow-[0_8px_32px_0_rgba(0,0,0,0.36)]
        rounded-3xl p-5
        text-slate-100
        transition-all duration-300 ease-out
        ${hoverEffect && onClick ? 'hover:bg-white/[0.12] hover:scale-[1.01] hover:shadow-[0_12px_40px_0_rgba(0,0,0,0.4)] cursor-pointer active:scale-95' : ''}
        ${className}
      `}
    >
      {/* Subtle top highlighting for 3D effect */}
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/20 to-transparent opacity-50" />
      {/* Subtle bottom shadow for grounded feel */}
      <div className="absolute inset-x-0 bottom-0 h-px bg-gradient-to-r from-transparent via-black/20 to-transparent opacity-50" />

      {children}
    </div>
  );
};

export const GlassInput: React.FC<React.InputHTMLAttributes<HTMLInputElement>> = (props) => (
  <div className="relative group">
    {/* Cutout effect background */}
    <input
      {...props}
      className={`
        w-full
        bg-black/20 
        backdrop-blur-md
        border border-white/10
        shadow-[inset_0_2px_4px_rgba(0,0,0,0.3)]
        rounded-2xl px-4 py-3.5
        text-white placeholder-white/30
        focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:border-teal-500/30 focus:bg-black/30
        transition-all duration-200
        disabled:opacity-50 disabled:cursor-not-allowed
        ${props.className || ''}
      `}
    />
  </div>
);

export const GlassButton: React.FC<React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: 'primary' | 'danger' | 'secondary' | 'ghost' }> = ({ children, variant = 'primary', className, ...props }) => {
  const baseStyle = "w-full font-medium py-3.5 rounded-2xl transition-all duration-300 transform active:scale-[0.98] shadow-lg flex items-center justify-center gap-2 relative overflow-hidden group";

  const variantStyles = {
    primary: "bg-gradient-to-br from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-white border border-white/20 shadow-teal-900/20",
    danger: "bg-gradient-to-br from-red-500/80 to-rose-600/80 hover:from-red-500 hover:to-rose-600 text-white border border-red-500/30 shadow-red-900/20",
    secondary: "bg-white/10 hover:bg-white/20 text-white border border-white/10 backdrop-blur-md",
    ghost: "bg-transparent hover:bg-white/5 text-white/80 hover:text-white border border-transparent shadow-none"
  };

  return (
    <button
      className={`${baseStyle} ${variantStyles[variant]} ${className || ''}`}
      {...props}
    >
      {/* Shine effect on hover */}
      <div className="absolute inset-0 -translate-x-full group-hover:translate-x-full transition-transform duration-700 bg-gradient-to-r from-transparent via-white/10 to-transparent" />
      <span className="relative z-10 flex items-center gap-2">{children}</span>
    </button>
  );
};