package com.vprofile.account;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

@ControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(UserNotFoundException.class)
    public String handleUserNotFoundException(UserNotFoundException ex, HttpServletRequest request) {
        request.setAttribute("errorMessage", ex.getMessage());
        return "forward:/WEB-INF/views/error/404.jsp";
    }

    @ExceptionHandler(BadCredentialsException.class)
    public String handleBadCredentialsException(BadCredentialsException ex, HttpServletRequest request) {
        return "redirect:/login?error";
    }

    @ExceptionHandler(org.springframework.security.core.userdetails.UsernameNotFoundException.class)
    public String handleUsernameNotFoundException(org.springframework.security.core.userdetails.UsernameNotFoundException ex, HttpServletRequest request) {
        return "redirect:/login?error";
    }

    @ExceptionHandler(Exception.class)
    public String handleGenericException(Exception ex, HttpServletRequest request) {
        request.setAttribute("errorMessage", "An unexpected error occurred. Please try again later.");
        return "forward:/WEB-INF/views/error/500.jsp";
    }
}
