# vis_filets_generator/profiles.rb
# Profils de filets : ISO 60 deg et Plastique V angle-limite

module VisFiletsGenerator
  module Profiles

    class BaseProfile
      attr_reader :r_major, :r_minor, :pitch, :feature_phases

      def initialize(r_major, r_minor, pitch)
        @r_major = r_major.to_f
        @r_minor = r_minor.to_f
        @pitch   = pitch.to_f
      end

      def radius_at(theta, z)
        phase = (z - theta * @pitch / (2.0 * Math::PI)) % @pitch
        interpolate(phase / @pitch)
      end

      private

      def interpolate(f)
        raise NotImplementedError
      end
    end

    # Profil V symetrique ISO 60 deg
    # Profondeur radiale = 5*H/8, H = P*sqrt(3)/2
    class IsoProfile < BaseProfile
      def initialize(r_major, pitch, r_minor = nil)
        if r_minor.nil?
          h       = pitch.to_f * Math.sqrt(3.0) / 2.0
          r_minor = r_major.to_f - 5.0 * h / 8.0
        end
        super(r_major, r_minor, pitch)
        @feature_phases = [[0.0, @r_major], [0.5, @r_minor]]
      end

      private

      def interpolate(f)
        if f < 0.5
          @r_major + (f / 0.5) * (@r_minor - @r_major)
        else
          @r_minor + ((f - 0.5) / 0.5) * (@r_major - @r_minor)
        end
      end
    end

    # Profil V optimise FDM — angle mesure depuis la VERTICALE (convention slicers FDM).
    # depth = (P/2) * tan(angle_vertical)
    # Plus l'angle vertical est grand, plus le flanc est incline et la profondeur grande.
    # Cap a 0.9*P pour eviter des filets excessivement profonds.
    # Exemples pour P=1.5mm (M10) :
    #   60 deg (vertical) => depth = 1.30 mm  (30 deg depuis l'horizontale — imprimante standard)
    #   45 deg (vertical) => depth = 0.75 mm  (45 deg — cas limite universel)
    #   70 deg (vertical) => depth = 1.35 mm  (cap 0.9P=1.35mm — refroidissement excellent)
    class PlasticProfile < BaseProfile
      def initialize(r_major, pitch, r_minor = nil, max_overhang_deg = 60.0, min_core_ratio = 0.70)
        if r_minor.nil?
          angle_rad   = [[max_overhang_deg.to_f, 5.0].max, 85.0].min * Math::PI / 180.0
          depth       = (pitch.to_f / 2.0) * Math.tan(angle_rad)
          r_minor_min = r_major.to_f * [[min_core_ratio.to_f, 0.05].max, 0.95].min
          r_minor     = [r_major.to_f - depth, r_minor_min].max
        end
        super(r_major, r_minor, pitch)
        @feature_phases = [[0.0, @r_major], [0.5, @r_minor]]
      end

      private

      def interpolate(f)
        if f < 0.5
          @r_major + (f / 0.5) * (@r_minor - @r_major)
        else
          @r_minor + ((f - 0.5) / 0.5) * (@r_major - @r_minor)
        end
      end
    end

  end
end
