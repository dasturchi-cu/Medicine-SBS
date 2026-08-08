export type CourseLanguage = "uz" | "ru" | "en";

export interface Course {
  id: string;
  title: string;
  language: CourseLanguage;
}

export interface Lesson {
  id: string;
  courseId: string;
  title: string;
  videoId: string;
  order: number;
  isFree: boolean;
}

export interface Banner {
  id: string;
  title: string;
  image: string;
  courseId: string;
  message: string;
  price: string;
  telegram: string;
}

export const courses: Course[] = [
  { id: "course-1", title: "Klinik anatomiya", language: "en" },
  { id: "course-2", title: "Farmakologiya Asoslari", language: "uz" },
  { id: "course-3", title: "Terapevtik amaliyot", language: "ru" },
];

export const lessons: Lesson[] = [
  { id: "lesson-1", courseId: "course-1", title: "Yuqori qo'l suyaklari kirish", videoId: "ab12CdE", order: 1, isFree: true },
  { id: "lesson-2", courseId: "course-1", title: "Ko'krak qafasi tuzilmalari", videoId: "Qw3Rt6Z", order: 2, isFree: false },
  { id: "lesson-3", courseId: "course-2", title: "Retseptor Turlari", videoId: "xYz982k", order: 1, isFree: true },
];

export const banners: Banner[] = [
  {
    id: "banner-1",
    title: "Bahorgi qabul boshlandi",
    image: "https://placehold.co/120x64",
    courseId: "course-1",
    message: "Kursga yozilish ochildi.",
    price: "299 000 so'm",
    telegram: "med_admin",
  },
  {
    id: "banner-2",
    title: "Yangi farmakologiya kursi",
    image: "https://placehold.co/120x64",
    courseId: "course-2",
    message: "Yangi oqim uchun maxsus narx.",
    price: "349 000 so'm",
    telegram: "med_admin",
  },
];
