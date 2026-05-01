# vis_filets_generator/profiles.rb
# Profils de filets : ISO 60 deg et Plastique trapezoidale 30 deg

module VisFiletsGenerator
  module Profiles

    class BaseProfile
      attr_reader :r_major, :r_minor, :pitch, :feature_phases

      def initialize(r_major, r_minor, pitch)
        @r_major = r_major.to_f
        @r_minor = r_minor.to_f
        @pitch   = pitch.to_f
      end

      # Rayon effectif pour un point de l'helice a (theta, z)
      def radius_at(theta, z)
        phase = (z - theta * @pitch / (2.0 * Math::PI)) % @pitch
        interpolate(phase / @pitch)
      end

      private

      def interpolate(f)
        raise NotImplementedError
      end
    end

    # Profil V symetrique ISO 60 deg (simplifie : crete et fond pointus)
    # Profondeur radiale = 5*H/8, H = P*sqrt(3)/2
    class IsoProfile < BaseProfile
      def initialize(r_major, pitch, r_minor = nil)
        if r_minor.nil?
          h       = pitch.to_f * Math.sqrt(3.0) / 2.0
          r_minor = r_major.to_f - 5.0 * h / 8.0
        end
        super(r_major, r_minor, pitch)
        # Phases de transition : crete (f=0) et fond (f=0.5)
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

    # Profil trapezoidale 30 deg optimise FDM (plats crete et fond)
    # Profondeur radiale = 0,65 * P
    # Structure : crete_plate | flanc_desc | fond_plat | flanc_mont | crete_plate
    #             0          0.125        0.375       0.625        0.875        1.0
    class PlasticProfile < BaseProfile
      def initialize(r_major, pitch, r_minor = nil)
        if r_minor.nil?
          r_minor = r_major.to_f - 0.65 * pitch.to_f
        end
        super(r_major, r_minor, pitch)
        # Toutes les phases de transition pour placement exact des vertices
        @feature_phases = [
          [0.0,   @r_major],
          [0.125, @r_major],
          [0.375, @r_minor],
          [0.5,   @r_minor],
          [0.625, @r_minor],
          [0.875, @r_major],
        ]
      end

      private

      def interpolate(f)
        if f < 0.125
          @r_major
        elsif f < 0.375
          t = (f - 0.125) / 0.25
          @r_major + t * (@r_minor - @r_major)
        elsif f < 0.625
          @r_minor
        elsif f < 0.875
          t = (f - 0.625) / 0.25
          @r_minor + t * (@r_major - @r_minor)
        else
          @r_major
        end
      end
    end

  end
end
