export interface Database {
  public: {
    Tables: {
      courses: {
        Row: {
          id: string;
          title_uz: string;
          title_ru: string;
          title_en: string;
          image: string | null;
          language: "uz" | "ru" | "en";
          created_at: string;
        };
      };
      lessons: {
        Row: {
          id: string;
          course_id: string;
          title: string;
          video_id: string;
          order: number;
          is_free: boolean;
          created_at: string;
        };
      };
      banners: {
        Row: {
          id: string;
          title: string;
          image: string;
          course_id: string;
          created_at: string;
        };
      };
    };
  };
}
