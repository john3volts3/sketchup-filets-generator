# vis_filets_generator/presets.rb
# Tables ISO M3-M20 (DIN 933 boulon hex, DIN 934 ecrou hex)

module VisFiletsGenerator
  module Presets

    # Cles : 'M3'..'M20'
    # :d     => diametre nominal (mm)
    # :pitch => pas normal ISO (mm)
    # :s_nut => travers-plats ecrou DIN 934 (mm)
    # :m_nut => hauteur ecrou DIN 934 (mm)
    ISO_PRESETS = {
      'M3'  => { d:  3.0, pitch: 0.50,  s_nut:  5.5, m_nut:  2.4 },
      'M4'  => { d:  4.0, pitch: 0.70,  s_nut:  7.0, m_nut:  3.2 },
      'M5'  => { d:  5.0, pitch: 0.80,  s_nut:  8.0, m_nut:  4.0 },
      'M6'  => { d:  6.0, pitch: 1.00,  s_nut: 10.0, m_nut:  5.0 },
      'M8'  => { d:  8.0, pitch: 1.25,  s_nut: 13.0, m_nut:  6.5 },
      'M10' => { d: 10.0, pitch: 1.50,  s_nut: 16.0, m_nut:  8.0 },
      'M12' => { d: 12.0, pitch: 1.75,  s_nut: 18.0, m_nut: 10.0 },
      'M16' => { d: 16.0, pitch: 2.00,  s_nut: 24.0, m_nut: 13.0 },
      'M20' => { d: 20.0, pitch: 2.50,  s_nut: 30.0, m_nut: 16.0 },
      'M22' => { d: 22.0, pitch: 2.50,  s_nut: 34.0, m_nut: 17.4 },
      'M24' => { d: 24.0, pitch: 3.00,  s_nut: 36.0, m_nut: 21.5 },
      'M27' => { d: 27.0, pitch: 3.00,  s_nut: 41.0, m_nut: 23.8 },
      'M30' => { d: 30.0, pitch: 3.50,  s_nut: 46.0, m_nut: 25.6 },
      'M32' => { d: 32.0, pitch: 3.50,  s_nut: 50.0, m_nut: 28.7 },
    }.freeze

    # Travers-plats ecrou pour une taille M non standard : formule DIN approchee
    def self.s_nut_for(d)
      preset = ISO_PRESETS.values.min_by { |p| (p[:d] - d).abs }
      return preset[:s_nut] if (preset[:d] - d).abs < 0.1
      (1.75 * d).round(1)
    end

    # Table des pas recommandes pour impression FDM (buse 0,4 mm)
    # Cle : diametre nominal (Float), valeur : pas recommande (mm)
    FDM_PITCH = {
       6.0 => 1.5,
       8.0 => 2.0,
      10.0 => 2.0,
      12.0 => 2.5,
      16.0 => 3.0,
      20.0 => 3.5,
      25.0 => 4.0,
    }.freeze

    def self.fdm_pitch_for(d)
      return FDM_PITCH[d] if FDM_PITCH.key?(d)
      # Interpolation lineaire sur la table
      keys = FDM_PITCH.keys.sort
      lo = keys.select { |k| k <= d }.last
      hi = keys.select { |k| k >= d }.first
      return (0.25 * d).round(2) if lo.nil? || hi.nil?
      return FDM_PITCH[lo] if lo == hi
      t = (d - lo).to_f / (hi - lo)
      (FDM_PITCH[lo] + t * (FDM_PITCH[hi] - FDM_PITCH[lo])).round(2)
    end

  end
end
