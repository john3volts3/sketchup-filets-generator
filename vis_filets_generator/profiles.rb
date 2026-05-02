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

    # Profil V ou trapezoidal FDM — angle mesure depuis la VERTICALE (convention slicers FDM).
    # L'angle des flancs reste CONSTANT = max_overhang_angle, quel que soit le pitch.
    # Si la profondeur theorique depasse (r_major - r_minor_min), le fond devient PLAT a r_minor_min
    # (profil trapezoidale) plutot que de changer l'angle.
    # Exemples pour P=1.5mm (M10), angle=60 deg :
    #   depth theorique = 1.30 mm — si min_core >= r_major-1.30 : trapeze, sinon V pur
    class PlasticProfile < BaseProfile
      def initialize(r_major, pitch, r_minor = nil, max_overhang_deg = 60.0, min_core_ratio = 0.70)
        angle_rad = [[max_overhang_deg.to_f, 5.0].max, 85.0].min * Math::PI / 180.0

        if r_minor.nil?
          depth_max   = (pitch.to_f / 2.0) * Math.tan(angle_rad)
          r_minor_min = r_major.to_f * [[min_core_ratio.to_f, 0.05].max, 0.95].min
          r_minor     = [r_major.to_f - depth_max, r_minor_min].max
        end

        super(r_major, r_minor, pitch)

        # f1 : fraction de pitch pour un flanc a l'angle fixe.
        # Si f1 < 0.5 : profil trapezoidale (fond plat entre f1 et 1-f1).
        # Si f1 = 0.5 : profil en V pur (angle atteint exactement r_minor).
        depth_actual = @r_major - @r_minor
        z_flank      = depth_actual / Math.tan(angle_rad)
        @f1          = [z_flank / @pitch, 0.5].min

        if @f1 < 0.5 - 1e-6
          @feature_phases = [[0.0, @r_major], [@f1, @r_minor], [1.0 - @f1, @r_minor]]
        else
          @feature_phases = [[0.0, @r_major], [0.5, @r_minor]]
        end
      end

      private

      def interpolate(f)
        if @f1 >= 0.5 - 1e-6
          # V pur
          if f < 0.5
            @r_major + (f / 0.5) * (@r_minor - @r_major)
          else
            @r_minor + ((f - 0.5) / 0.5) * (@r_major - @r_minor)
          end
        else
          # Trapeze : flancs a angle fixe, fond plat a r_minor
          if f < @f1
            @r_major + (f / @f1) * (@r_minor - @r_major)
          elsif f <= 1.0 - @f1
            @r_minor
          else
            @r_minor + ((f - (1.0 - @f1)) / @f1) * (@r_major - @r_minor)
          end
        end
      end
    end

  end
end
