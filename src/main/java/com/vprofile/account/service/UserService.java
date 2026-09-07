package com.vprofile.account.service;

import java.util.List;

import com.vprofile.account.model.User;

/** {@author ankit}!*/
public interface UserService {
	/** {@inheritDoc}} !*/
    void save(User user);
    /** {@inheritDoc}} !*/
    User findByUsername(String username);
    User findById(long id);
    /*public void updateUser(User user);*/
    public List <User> getList();
}
